% signal = ersp_generate_signal_fromclass(class, epochs, varargin)
%
%       Takes an ERSP activation class, determines single parameters given
%       the deviations/slopes in the class, and returns a signal generated
%       using those parameters.
%
% In:
%       class - 1x1 struct, the class variable
%       epochs - single epoch configuration struct containing at least
%                sampling rate (srate), epoch length (length), and total
%                number of epochs (n)
%
% Optional (key-value pairs):
%       epochNumber - current epoch number. this is required for slope
%                     calculation, but defaults to 1 if not indicated
%       baseonly - whether or not to only plot the base signal, without any
%                  deviations or slopes (1|0, default 0)
%
% Out:  
%       signal - row array containing the simulated noise activation signal
%
% Usage example:
%       >> epochs.n = 100; epochs.srate = 500; epochs.length = 1000;
%       >> ersp.frequency = 20; ersp.amplitude = 1; ersp.phase = 0;
%       >> ersp.modulation='pac'; ersp.modFrequency=2; ersp.modPhase= -.25;
%       >> signal = ersp_generate_signal_fromclass(ersp, epochs, 1);
% 
%                    Copyright 2017 Laurens R Krol
%                    Team PhyPA, Biological Psychology and Neuroergonomics,
%                    Berlin Institute of Technology

% 2017-10-19 lrk
%   - Added broadband base activation
% 2017-07-13 lrk
%   - Fixed bug where modMinAmplitude was ignored for burst/invburst
%     baseonly signal
% 2017-06-20 lrk
%   - Changed variable names for consistency
%   - Added prestimulus attenuation to PAC
% 2017-06-16 First version

% This file is part of Simulating Event-Related EEG Activity (SEREEGA).

% SEREEGA is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.

% SEREEGA is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with SEREEGA.  If not, see <http://www.gnu.org/licenses/>.

function signal = ersp_generate_signal_fromclass(class, epochs, varargin)

% parsing input
p = inputParser;

addRequired(p, 'class', @isstruct);
addRequired(p, 'epochs', @isstruct);

addParameter(p, 'epochNumber', 1, @isnumeric);
addParameter(p, 'baseonly', 0, @isnumeric);

parse(p, class, epochs, varargin{:})

class = p.Results.class;
epochs = p.Results.epochs;
epochNumber = p.Results.epochNumber;
baseonly = p.Results.baseonly;

if baseonly
    % generating base signal
    if class.bandWidth > 0
        class.frequency = [class.frequency - class.bandWidth / 2, class.frequency + class.bandWidth / 2]; end
    
    if strcmp(class.modulation, 'none')
        signal = ersp_generate_signal(class.frequency, class.amplitude, class.phase, epochs.srate, epochs.length);
    elseif ismember(class.modulation, {'burst', 'invburst'})
        signal = ersp_generate_signal(class.frequency, class.amplitude, class.phase, epochs.srate, epochs.length, ...
                'modulation', class.modulation, 'modLatency', class.modLatency, 'modWidth', class.modWidth, 'modTaper', class.modTaper, 'modMinAmplitude', class.modMinAmplitude);
    elseif strcmp(class.modulation, 'pac')
        signal = ersp_generate_signal(class.frequency, class.amplitude, class.phase, epochs.srate, epochs.length, ...
                'modulation', class.modulation, 'modFrequency', class.modFrequency, 'modPhase', class.modPhase, 'modMinAmplitude', class.modMinAmplitude, ...
                'modPrestimPeriod', class.modPrestimPeriod, 'modPrestimTaper', class.modPrestimTaper, 'modPrestimAmplitude', class.modPrestimAmplitude);
    end
else
    % checking probability
    if rand() > class.probability + class.probabilitySlope * epochNumber / epochs.n
        % returning flatline
        signal = zeros(1, floor((epochs.length/1000)*epochs.srate));
    else

        % obtaining specific base values
        frequency = utl_apply_dvslope(class.frequency, class.frequencyDv, class.frequencySlope, epochNumber, epochs.n);
        if class.bandWidth > 0
            bandWidth = utl_apply_dvslope(class.bandWidth, class.bandWidthDv, class.bandWidthSlope, epochNumber, epochs.n);
            frequency = [frequency - bandWidth/2, frequency + bandWidth/2];
        end
        
        amplitude = utl_apply_dvslope(class.amplitude, class.amplitudeDv, class.amplitudeSlope, epochNumber, epochs.n);
        
        if ~isempty(class.phase)
            phase = utl_apply_dvslope(class.phase, class.phaseDv, class.phaseSlope, epochNumber, epochs.n);
        else
            phase = class.phase;
        end

        if strcmp(class.modulation, 'none')
            % generating signal
            signal = ersp_generate_signal(frequency, amplitude, phase, epochs.srate, epochs.length);
        elseif ismember(class.modulation, {'burst', 'invburst'})
            % obtaining specific burst values
            latency = utl_apply_dvslope(class.modLatency, class.modLatencyDv, class.modLatencySlope, epochNumber, epochs.n);
            width = utl_apply_dvslope(class.modWidth, class.modWidthDv, class.modWidthSlope, epochNumber, epochs.n);
            taper = utl_apply_dvslope(class.modTaper, class.modTaperDv, class.modTaperSlope, epochNumber, epochs.n);
            minAmplitude = utl_apply_dvslope(class.modMinAmplitude, class.modMinAmplitudeDv, class.modMinAmplitudeSlope, epochNumber, epochs.n);

            % generating signal
            signal = ersp_generate_signal(frequency, amplitude, phase, epochs.srate, epochs.length, ...
                    'modulation', class.modulation, 'modLatency', latency, 'modWidth', width, 'modTaper', taper, 'modMinAmplitude', minAmplitude);
        elseif strcmp(class.modulation, {'pac'})
            % obtaining specific pac values
            modFrequency = utl_apply_dvslope(class.modFrequency, class.modFrequencyDv, class.modFrequencySlope, epochNumber, epochs.n);
            minAmplitude = utl_apply_dvslope(class.modMinAmplitude, class.modMinAmplitudeDv, class.modMinAmplitudeSlope, epochNumber, epochs.n);
            if ~isempty(class.modPhase)
                modPhase = utl_apply_dvslope(class.modPhase, class.modPhaseDv, class.modPhaseSlope, epochNumber, epochs.n);
            else
                modPhase = class.modPhase;
            end 

            % generating signal
            signal = ersp_generate_signal(frequency, amplitude, phase, epochs.srate, epochs.length, ...
                    'modulation', class.modulation, 'modFrequency', modFrequency, 'modPhase', modPhase, 'modMinAmplitude', minAmplitude, ...
                    'modPrestimPeriod', class.modPrestimPeriod, 'modPrestimTaper', class.modPrestimTaper, 'modPrestimAmplitude', class.modPrestimAmplitude);
        end

    end
end

end