function [ ECG BaselineWander ] = BaselineWanderRemovalSplines( ECG, QRS_locations, sampling_rate)

% Description:
% Performs baseline wander removal with cubic splines method. Estimates the
% baseline wander in the PQ silence segment and then substract it from ECG.
% 
% Arguments:
%   + ECG: signal to be cleaned.
%   + sampling_rate: sampling rate of the ECG.
% 
% Output:
%   + ECG: clean ECG.
% 
% References:
% 
% S�rnmo L, Laguna P. Bioelectrical Signal Processing in Cardiac
% and Neurological Applications. Elsevier, 2005. ISBN
% 0-12-437552-9. Page 457.
% 
% Limits and Known bugs:
% 
% Author: Mariano Llamedo Soria (llamedom at {electron.frba.utn.edu.ar; unizar.es}
% Birthdate  : 23/8/2011
% Last update: 23/8/2011

[ECG_size ECG_leads] = size(ECG);

QRS_locations = QRS_locations(QRS_locations > round(0.2*sampling_rate));

cant_QRS = length(QRS_locations);

aux_idx = arrayfun(@(a)( QRS_locations(a) - round(0.2*sampling_rate): ...
                         min(ECG_size, QRS_locations(a) - round(0.1*sampling_rate))) , ...
                   1:cant_QRS, 'UniformOutput', false);

PQ_estimations = cell2mat(cellfun(@(a)(mean(ECG(a,:),1)), colvec(aux_idx), 'UniformOutput', false));
PQ_sample = cell2mat(cellfun(@(a)(mean(a)), colvec(aux_idx), 'UniformOutput', false));

BaselineWander = spline( [ 1       ; PQ_sample      ; ECG_size  ], ...
                [ ECG(1,:); PQ_estimations ; ECG(end,:)]', ...
               1:ECG_size )';

ECG = ECG - BaselineWander;
