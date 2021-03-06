function out_freq_spec = fn_propagate_spectrum(freq, in_freq_spec, ph_vel, dists, varargin);
%USAGE
%	out_freq_spec=fn_propagate_spectrum(freq, in_freq_spec, ph_vel, dists [, amps]);
%AUTHOR
%	Paul Wilcox (Oct 2007)
%SUMMARY
%	Applies phase shifts to spectrum (in_spec) to simulate propagation delays associated
%with one or more propagation distances and returns a phase-shifted spectrum for each
%propagation distance specified.
%	Note that no checks are made to see if propagation distance(s) is/are small enough to be
%accommodated by the number of points in in_freq_spec. If too large a propagation distance is
%specified then signals will be wrapped when out_freq_spec are converted back to time domain.
%INPUTS
%	freq - frequency vector corresponding to spectra
%	in_freq_spec - the spectrum that will be propagated
%	ph_vel - phase velocity: either a single number for non-dispersive propagation 
%				or a 2 column matrix where 1st column is frequency and second is phase velocity
%	dists - required propagation distance or vector if spectra for multiple distances are required
%	amps[ones(size(dists))] - optional vector of corresponding amplitudes
%OUTPUTS
%	out_freq_spec - vector (or matrix if length(dists)>1) of the resulting
%propagated spectra. If in matrix form, the spectra are in columns, and the number of columns is
%equal to length(dists).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin>4
   amps = varargin{1};
else
   amps = ones(size(dists));
end;

%get wavenumber spectrum (interpolate if nesc)
if length(ph_vel)==1
   k = 2 * pi * freq / ph_vel;
else
   temp_f = ph_vel(:,1);
   temp_v = ph_vel(:,2);
   if freq(1)<temp_f(1)
	  temp_f = [freq(1);temp_f];
 	  temp_v = [temp_v(1);temp_v];
  end;
  if freq(end)>temp_f(end)
	  temp_f = [temp_f;freq(end)];
 	  temp_v = [temp_v;temp_v(end)];
  end;
  warning off MATLAB:divideByZero
   k = 2 * pi * freq ./ interp1(temp_f,temp_v,freq,'cubic');
   warning on MATLAB:divideByZero
   k(find(isnan(k))) = 0;
end;
%do the propagation
out_freq_spec = zeros(length(freq),length(dists));
for ii = 1:length(dists)
   out_freq_spec(:,ii) = amps(ii) * in_freq_spec(:) .* exp(-i * k(:) * dists(ii));
end;

return;