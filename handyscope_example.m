%Example of using Handyscope with chirp excitation and detection
%Clear and close everything
clear scp
clear gen
clear all;
close all;
clc

%Handyscope scope parameters
scp_sens = 0.4; %Sensitivity of input (V) can be 0.2,0.4,0.8,2,4,8,20,40,80
scp_sample_freq = 0.5e6; %Hz
scp_sample_pts = 2^10; 
scp_averages = 8; %number of averages
scp_pretrig = 0; %proportion of points taken prior to trigger - not sure if this works
scp_resolution = 14; %scope bit depth

%Handyscope function generator parameters
gen_pts = scp_sample_pts;%2^15; %number of points in the afg signal, effectively sets the repeat rate (this needs checking!!)
gen_amp = 12; %Signal amplitude in V+-, max 12V

%Transmit signal details
centre_freq = 120e3; %Hz
equiv_cycles = 5
stretch_factor = 16; 
%set stretch_factor to 1 to use unchirped signal with equiv_cycles, 
%otherwise transmit signal will be chirp with: 
%   duration = equiv_cycles * stretch_factor / centre_freq
%SNR is proportional to sqrt(duration); practical limit is number of points
%available in signal generator memory

%For dummy data if no Handyscope found
dummy_noise_level = 0.05;
dummy_number_of_reflections = 3;
%--------------------------------------------------------------------------
%Connect Handyscope and run the code to load the library
import LibTiePie.Const.*
import LibTiePie.Enum.*
if ~exist('LibTiePie', 'var')
    % Open LibTiePie:
    LibTiePie = LibTiePie.Library;
end

%Search for devices and list them:
LibTiePie.DeviceList.update();
for i = 0: LibTiePie.DeviceList.Count - 1
    item = LibTiePie.DeviceList.getItemByIndex(i);
    fprintf('Found %d: %s, s/n: %u\n', i, item.Name, item.SerialNumber);
    if item.Name == "Handyscope HS5-220"
        gen = item.openGenerator();
        fprintf('Generator Opened\n');
    elseif item.Name == "Combined Instrument"
        scp = item.openOscilloscope();
        fprintf('Scope Opened\n');
    end
end
clear item;

if ~exist('scp', 'var')
    fprintf('No Handyscope found\n');
    hs_present = 0;
else
    hs_present = 1;
end

if hs_present
    %Set up the scope
    scp.MeasureMode = MM.BLOCK;
    scp.RecordLength = scp_sample_pts;
    scp.SampleFrequency = scp_sample_freq;
    scp.PreSampleRatio = scp_pretrig;
    scp.Resolution = scp_resolution;
    scp.TriggerTimeOut = 1;
    
    for ch = scp.Channels
        ch.Enabled = true;
        ch.Range = scp_sens; % all channels set to same gain
        ch.Coupling = 2; % all channels set to DC coupling
        clear ch;
    end
    
    %Set up the function generator
    gen.OutputOn = false;
    gen.SignalType = ST.ARBITRARY;
    gen.FrequencyMode = FM.SAMPLEFREQUENCY;
    gen.Frequency = scp_sample_freq;
    gen.Amplitude = gen_amp;
    gen.Offset = 0;
end

%Create the input signal
time_step = 1 / scp_sample_freq;
centre_time = 1 / centre_freq * equiv_cycles * 2;
if stretch_factor <= 1
    [time, transmit_signal] = fn_create_input_signal(gen_pts, centre_freq, time_step, equiv_cycles, 'hanning', centre_time);
else
    [time, transmit_signal, unchirped_signal] = fn_create_gaussian_chirp(gen_pts, time_step, centre_freq, equiv_cycles, stretch_factor);
    dechirp_correction_spec = conj(fft(transmit_signal));
    dechirp_correction_spec(length(dechirp_correction_spec) / 2 + 1:end) = 0;
    %Following lines add some extra factors for display purposes in
    %order for dechirped signals to line up with chirped ones and have same
    %amplitude. Critical bit that actually does the de-chirping is just the
    %conj(fft(transmit_signal)) above.
    f = [0: length(dechirp_correction_spec) - 1]' / (length(dechirp_correction_spec) * time_step);
    dechirp_correction_spec = dechirp_correction_spec / stretch_factor / 2 .* exp(-1i * 2 * pi * f * stretch_factor * equiv_cycles / centre_freq / 2);
end


if hs_present
    %Load input signal into generator
    gen.setData(real(transmit_signal));
    gen.OutputOn = true;
    
    %Disable all channel trigger sources:
    for ch = scp.Channels
        ch.Trigger.Enabled = false;
        clear ch;
    end
    triggerInput = scp.TriggerInputs(8);%(TIID.GENERATOR_NEW_PERIOD) or TIID.GENERATOR_START or TIID.GENERATOR_STOP or TIID.GENERATOR_NEW_PERIOD
    
    %Start function generator
    triggerInput.Enabled = true;
    gen.OutputOn = true;
    gen.start();
end

%calculate the timebase for plotting
t = ([1: scp_sample_pts]' - (scp_sample_pts - round((1 - scp_pretrig) * scp_sample_pts))) / scp_sample_freq;

figure;
while 1
    %Get data and average it
    raw_data = 0;
    if ~hs_present %dummy signal if no HS present to test chirp/dechirp - just delay transmit signal a few times and pretend it is the received signal
        dummy_data = 0;
        for i = 1:dummy_number_of_reflections
            dummy_data = dummy_data + circshift(real(transmit_signal), randi(length(transmit_signal) / 2, 1)) * rand(1) * scp_sens;
        end
    end
            
    for avs = 1:scp_averages
        if hs_present
            scp.start();
            while ~scp.IsDataReady
                pause(0.01);
            end
            new_data = scp.getData();
        else
            %if no scope add some noise to dummy data as current signal
            
            new_data = dummy_data + randn(size(t)) * dummy_noise_level * scp_sens;
            pause(0.01);
        end
        raw_data = raw_data + new_data;
        average_data = raw_data / avs;
        if stretch_factor > 1
            %dechirp average data
            dechirped_data = real(ifft(fft(average_data) .* dechirp_correction_spec));
        else
            dechirped_data = average_data;
        end
        
        %plot
        clf;
        plot(t, new_data);
        hold on;
        plot(t, average_data, 'r');
        plot(t, dechirped_data, 'g');
        xlabel('Time (s)');
        ylim([-1, 1] * scp_sens);
        title(sprintf('Averages: %i / %i', avs, scp_averages));
        legend('Raw', 'Average', 'De-chirped average');
        drawnow;
    end
    
end

clear scp
clear gen