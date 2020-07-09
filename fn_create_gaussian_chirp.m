function [time, chirped_signal, unchirped_signal] = fn_create_gaussian_chirp(pts, time_step, centre_freq, equiv_cycles, stretch_factor)
%SUMMARY
%   Creates a chirp with same frequency bandwidth as a presribed Gaussian
%   windowed toneburst (and also outputs the un-chirped signal)
%USAGE
%   [time, chirped_signal, unchirped_signal] = fn_create_gaussian_chirp(pts, time_step, centre_freq, equiv_cycles, stretch_factor)
%INPUTS
%   pts - number of points in output signals
%   time_step - time step between points in output signals
%   centre_freq - centre frequency of output signal
%   equiv_cycles - number of cycles (defined by -40 dB points) in unchirped
%   signal
%   stretch_factor - stretch factor describing how many times longer the chirped
%   signal will be in time than the unchirped signal
%OUTPUTS
%   time - time vector
%   chirped_signal - chirped signal
%   unchirped_signal - unchirped signal

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
db_down = 60;

beta = 10 ^ (db_down / 20);
time = [0:pts-1] * time_step;
time = time(:);
df = 1 / (pts * time_step);
f = [0:pts/2-1]' * df;
sigma1 = equiv_cycles / centre_freq / sqrt(8 * log(beta));
sigma2 = sigma1 * stretch_factor;
shift1 = exp(-2 * pi * i * f * equiv_cycles / centre_freq / 2);
shift2 = exp(-2 * pi * i * f * equiv_cycles * stretch_factor / centre_freq / 2);
S1 = exp(-0.5 * (2 * pi * (f - centre_freq)* sigma1) .^ 2) .* shift1;
s1 = ifft(S1, pts);
S2 = exp(-0.5 * (2 * pi * (f - centre_freq)* sigma1) .^ 2) .* exp(0.5 * i * (2 * pi * (f - centre_freq)) .^ 2 * sqrt(stretch_factor ^ 2 - 1) * sigma1 ^ 2) .* shift2;
s2 = ifft(S2, pts);
unchirped_signal = s1 / max(abs(s1));
chirped_signal = s2 / max(abs(s2));
return;