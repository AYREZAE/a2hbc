function [ Labels, ConfusionMatrix, LabelList ] = a2hbc_main(varargin)

% A2HBC main script
% -----------------
% See a2hbc.m in the parent directory or the documentation for help.
% 
% Author: Mariano Llamedo Soria (llamedom at {electron.frba.utn.edu.ar; unizar.es}
% Birthdate  : 16/8/2011
% Last update: 9/2/2012

%% Constants and definitions

a2hbc_header;

% some variable declarations;
Labels = [];
ConfusionMatrix = [];
LabelList = [];
true_labels = [];
this_iter_cm = nan(typical_cant_labels);
recording_name_old = [];
bArgCheckPassed = false;
CantSamplesClose = 10;
CantSamplesFar = 10;

%% Argument parsing

%argument definition
p = inputParser;   % Create instance of inputParser class.
p.addParamValue('recording_name', [], @(x)( ischar(x)));
p.addParamValue('recording_format', [], @(x)( any(strcmpi(x,cKnownFormats))) );
p.addParamValue('ECG', [], @(x)(isnumeric(x)) );
p.addParamValue('ECG_header', [], @(x)(isstruct(x)) );
p.addParamValue('QRS_annotations', [], @(x)( isnumeric(x) && all(x > 0) ) );
p.addParamValue('op_mode', 'auto', @(x)( (isnumeric(x) && x >= 1  && x <= maxOperMode) || any(strcmpi(x,cKnownModesOfOperation))) );
p.addParamValue('cant_pids', 1, @(x)(isnumeric(x) && x > 0 ) );
p.addParamValue('this_pid', 1, @(x)(isnumeric(x) && x > 0 ) );
p.addParamValue('CacheData', true, @(x)(islogical(x)) );
p.addParamValue('InteractiveMode', false, @(x)(islogical(x)) );
p.addParamValue('SimulateExpert', false, @(x)(islogical(x)) );
p.addParamValue('tmp_path', [], @(x)(ischar(x)) );
p.addParamValue('NumOfClusters', 12, @(x)(isnumeric(x) && x > 1 ) );
p.addParamValue('ClusteringRepetitions', 1, @(x)(isnumeric(x) && x > 0 && x <= 10 ) );
p.addParamValue('ClusterPresence', 75, @(x)(isnumeric(x) && x >= 0 && x <= 100 ) );
p.addParamValue('Repetitions', 1, @(x)(isnumeric(x) && x > 0 ) );


try
    p.parse( varargin{:} );
catch MyError
    rethrow(MyError);    
end

recording_name = p.Results.recording_name;
recording_format = p.Results.recording_format;
ECG_total = p.Results.ECG;
ECG_header = p.Results.ECG_header;
QRS_annotations = p.Results.QRS_annotations;
bCache = p.Results.CacheData;
op_mode = p.Results.op_mode;
cant_pids = p.Results.cant_pids;
this_pid = p.Results.this_pid;
tmp_path = p.Results.tmp_path;
bInteractiveMode = p.Results.InteractiveMode;
bSimulateExpert = p.Results.SimulateExpert;
CantClusters = p.Results.NumOfClusters;
iter_times = p.Results.ClusteringRepetitions;
cluster_presence = p.Results.ClusterPresence;
Repetitions = p.Results.Repetitions;


% Dont know why this variable uses a lot of bytes to store at disk.
clear p

%% Start of the algorithm

if( bHaveUserInterface )
    if( isempty(varargin) )
        bInteractiveMode = true;
    end
else
    bInteractiveMode = false;
end

% if( bInteractiveMode )
%     %User can exit before starting.
%     bUserExit = false;
% 
%     %Check the user arguments
%     CheckArguments;
%     
% %     %and give the chance to change them
% %     UserInteraction;
%     
%     bArgCheckPassed = true;
%     
% else
% end

bUserExit = false;
bRecordingChanged = true;

repeat_idx = 1;
ConfusionMatrix = zeros(typical_cant_labels, typical_cant_labels,Repetitions);

while ( ~bUserExit && repeat_idx <= Repetitions )

    try

        %% work starts here
        
        if( bRecordingChanged )
            % new recording, needs processing

            %% Argument check
                
            CheckArguments;
            
            %% Prepare jobs to perform.

            cant_QRS_locations = length(QRS_locations);

            %PID parsing
            if( cant_pids > 1 )
                
                max_recommended_can_pids = max(1, round( cant_QRS_locations / min_QRS_perPID ));

                cant_pids = min(cant_pids, max_recommended_can_pids);
                
                [pid_starts, pid_ends] = TaskPartition( cant_QRS_locations, cant_pids);

                if( this_pid <= cant_pids )
                    QRS_start_idx = pid_starts(this_pid);
                    QRS_end_idx = pid_ends(this_pid);
                else
                    % Classification only PIDs
                    QRS_start_idx = 1;
                    QRS_end_idx = cant_QRS_locations;
                end

            else
                QRS_start_idx = 1;
                QRS_end_idx = cant_QRS_locations;
            end

            % Activate the progress_struct bar.
            progress_struct = progress_bar('on', ['Processing ' rec_filename ' recording' ]);
            position_waitbar;

            %start of the progress_struct loop 0%
            progress_struct = progress_bar(0, progress_struct);

            % Update point
            progress_struct = progress_bar(progress_struct, 'Initializing');

            % calculate iterations 
            % QRS_locations = QRS_locations(QRS_start_idx:QRS_end_idx);
            cant_QRS2do = QRS_end_idx - QRS_start_idx + 1;
            cant_iter = ceil(cant_QRS2do * heasig.nsig / maxQRSxIter / 2);
            [iter_starts, iter_ends] = TaskPartition( cant_QRS2do, cant_iter);

            if(cant_iter > 1 && ~isempty(ECG_total) )
                warning('a2hbc:TwoManySamples', ['Risk of Out of Memory, try smaller ECG blocks ( max ' num2str(maxQRSxIter) ' samples) or to read directly from files.'])
            end

            %% Calculate accesories signals

            overlapping_samples = overlapping_time * sampling_rate;

            queue2read;
            %load low-pass preprocessing filter.
            load( ['LP Fs ' num2str(sampling_rate) 'Hz - Fc 35Hz - 80db stop.mat' ]);
            LPsize = length(LP.numerator);
            delayLP = round((LPsize-1)/2);

            % Wavelet transform filter bank design
            scales = 1:6;
            CantScales = length(scales);
            MaxScales = max(scales);
            scale_idx = nan(MaxScales,1);

            filters_cache_filename = ['wt_filters_' num2str(MaxScales) ' scales_' num2str(sampling_rate) ' Hz.mat' ];
            if( exist(filters_cache_filename, 'file') )
                load( filters_cache_filename );
            else
                q_filters = qs_filter_design(MaxScales, sampling_rate);
            end
            wt_delay = 0;
            for ii = 1:CantScales
                %indice para saber que escala corresponde a cada columna de MyWavelets
                scale_idx(scales(ii)) = ii;
                aux_delay = grpdelay(q_filters(scales(ii)),1);
                cant_casc = length(aux_delay);
                aux_delay = round( sum(aux_delay) );
                wt_delay = max(wt_delay, aux_delay+cant_casc);
            end

            % RR interval sequence
            RR_intervals = diff(QRS_locations, 1);
            RR_intervals = [ RR_intervals(1); RR_intervals ];

            dRR_intervals = diff(RR_intervals, 1);
            dRR_intervals = [ dRR_intervals(2); dRR_intervals(2); dRR_intervals(2:end) ];

            % interval resampling.
            RR_intervals = RR_intervals * sampling_rate / heasig.freq;
            dRR_intervals = dRR_intervals * sampling_rate / heasig.freq;

            %the trained linear classifier.
            % load('ldc_classifier.mat');
            load('global_classifier.mat');

            Labels = nan(cant_QRS2do,1);

            if( this_pid > cant_pids )
                %% Classification only PIDs

                unqueue2read;
                
                % Wait other PIDS sync here after Master build the featmat
                % file.
                %last pid
                bContinue = true;
                CachedFeatMatFileName = [tmp_path 'tmpfile_' rec_filename '_featmatrix.mat' ];

                %Wait for Time2WaitPIDs seconds the finalization of all PIDs. Otherwise exit
                %with error.
                Start2Wait = tic();

                while(bContinue)

                    queue2read;

                    try

                        if( exist( CachedFeatMatFileName, 'file') )
                            % exit the waiting loop.
                            bContinue = false;
                        else
                            error('a2hbc:PIDnotFinished', 'Handled error');
                        end

                    catch ME

                        unqueue2read;

                        if( strfind(ME.identifier, 'a2hbc') )
                            if( toc(Start2Wait) > 2*Time2WaitPIDs )
                                error('a2hbc:PIDnotFinished', 'Timeout. Classification-only Slave give up waitng Master.');
                            end
                            pause(60);
                        else
                            rethrow(ME)
                        end
                    end


                end
                
            end
            
            
            %% ECG processing

            CachedFeatMatFileName = [tmp_path 'tmpfile_' rec_filename '_featmatrix.mat' ];

            if( exist( CachedFeatMatFileName, 'file') )

%                 %When restoring, only continues the last (or only) PID.
%                 if( this_pid ~= cant_pids )
%                     warning('a2hbc:NoWorkForMe','Feature Matrix already calculated. Exiting.')
%                     return                    
%                 end

                % Update point
                progress_struct = progress_bar(progress_struct, 'Restoring cached feature matrix');
                
                % restore cached data.
                load(CachedFeatMatFileName);
                unqueue2read;

            else
                %% Calculate last accesories signals
                unqueue2read;
                
                % Update point
                progress_struct = progress_bar(progress_struct, 'PCA projection');

                if( ~isempty(ECG_total) )
                    autovec = PCA_proj_basis(ECG, QRS_locations, sampling_rate, q_filters);
                else
                    autovec = PCA_proj_basis(recording_name, recording_format, q_filters);
                end

                %% Iterations over the whole ECG recording

                start_iter = 1;

                %check for previous iterations already done, and try to restore.
                if( cant_pids == 1 )
                    if( cant_iter > 1)
                        for ii = 1:cant_iter
                            aux_filename = [tmp_path 'tmpfile_' rec_filename '_featmatrix_iteration_' num2str(ii) '_of_' num2str(cant_iter) '.mat' ];
                            if( exist(aux_filename, 'file') )
                                start_iter = ii+1;
                            else
                                break
                            end
                        end
                    end
                else
                    for ii = 1:cant_iter
                        aux_filename =  [tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_thispid_' num2str(this_pid) '_iteration_' num2str(ii) '_of_' num2str(cant_iter) '.mat' ];
                        if( exist(aux_filename, 'file') )
                            start_iter = ii+1;
                        else
                            break
                        end
                    end
                end

                for this_iter = start_iter:cant_iter

                    %start of the progress_struct loop 0%
                    progress_struct = progress_bar(0, progress_struct);

                    this_iter_QRS_start_idx = QRS_start_idx - 1 + iter_starts(this_iter);
                    this_iter_QRS_end_idx = QRS_start_idx - 1 + iter_ends(this_iter);

                    this_iter_cant_QRS = this_iter_QRS_end_idx - this_iter_QRS_start_idx + 1;

                    this_iter_ECG_start_idx = max(1, QRS_locations(this_iter_QRS_start_idx) - overlapping_samples);
                    this_iter_ECG_end_idx = min(heasig.nsamp, QRS_locations(this_iter_QRS_end_idx) + overlapping_samples);

                    %% ECG Recording reading
                    % Update point
                    progress_struct = progress_bar(progress_struct, 'ECG Recording reading');

                    if( isempty(recording_name) )
                        ECG = ECG_total(this_iter_ECG_start_idx:this_iter_ECG_end_idx,:);
                    else
                        %% read from file
                        
                        queue2read;

%                         try
                            ECG = read_ECG(recording_name, recording_format, this_iter_ECG_start_idx, this_iter_ECG_end_idx );
%                         catch ME_ecg_read
%                             
%                             if( strfind(ME_ecg_read.identifier, 'read_ECG') )
%                                 
%                             else
%                                 
%                             end
%                         end
                        
                        unqueue2read;

                        %convert ADC samples (int16) to real units data.
                        ECG = ADC2realunits(double(ECG), heasig.adczero, heasig.gain);

                    end

                    % Update point
                    progress_struct = progress_bar(progress_struct, 'Resampling');

                    %% Preprocessing

                    this_iter_QRS_seq_idx = this_iter_QRS_start_idx:this_iter_QRS_end_idx;

                    %resample to sampling_rate Hz
                    ECG = resample(ECG, sampling_rate, heasig.freq);
                    this_iter_QRS_locations = QRS_locations(this_iter_QRS_seq_idx) - this_iter_ECG_start_idx + 1;
                    this_iter_QRS_locations = round(this_iter_QRS_locations * sampling_rate / heasig.freq);
            %         this_iter_true_labels = true_labels(this_iter_QRS_seq_idx);
                    this_iter_ECG_resampled_size = size(ECG,1);

                    if( heasig.nsig > 2 ) 
                        %multilead approach.
                        % project ECG and wtECG to obtain PCA components
                        ECG = ECG * autovec(:,1:2);
            %             wtECG = cellfun(@(a)( a * autovec(:,1:2) ), mat2cell(wtECG, this_iter_ECG_resampled_size, heasig.nsig, ones(1,CantScales) ), 'UniformOutput', false);
            %             wtECG = cell2mat(wtECG);
                    end

                    % Update point
                    progress_struct = progress_bar(progress_struct, 'Filtering');

                    %Low pass filtering @ 35Hz => ECG recovery
                    ECG = filter(LP, ECG);
                    %delay compensation.
                    ECG = [ zeros(delayLP, size(ECG,2) ) ;ECG(LPsize:end,:) ; zeros(delayLP, size(ECG,2))];

                    %Quito la linea de base.
                %     ECG = BaselineWanderRemovalMedian( ECG, sampling_rate);
                    ECG = BaselineWanderRemovalSplines( ECG, this_iter_QRS_locations, sampling_rate);

                    % Update point
                    progress_struct = progress_bar(progress_struct, 'Wavelet transform calculation');

                    wtECG = qs_wt(ECG, scales, sampling_rate, q_filters);
                    
                    %% Features Calculation

                    % Update point
                    progress_struct = progress_bar(progress_struct, 'Features calculation');

                    this_iter_seq_idx = 1:this_iter_cant_QRS;

                    % log(RRactual)
                    %%%%%%%%%%%%%%%
                    featMat_ldc = log(colvec(RR_intervals(this_iter_QRS_seq_idx))/sampling_rate);

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(RRpost)
                    %%%%%%%%%%%%%%%

                    featMat_ldc = [ featMat_ldc log(colvec(RR_intervals(min(cant_QRS_locations, this_iter_QRS_seq_idx+1)))/sampling_rate)];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(RRmean1)
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)( find(  this_iter_QRS_locations >= (this_iter_QRS_locations(a) - 1*60*sampling_rate) & ... 
                                                    this_iter_QRS_locations <= this_iter_QRS_locations(a) )), ...
                                       this_iter_seq_idx, 'UniformOutput', false);

                    aux_featval = cellfun(@(a)(mean(RR_intervals(a))/sampling_rate), aux_idx);
                    featMat_ldc = [ featMat_ldc colvec(log(aux_featval)) ];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(RRmean20)
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)( find(  QRS_locations >= (QRS_locations(a) - 20*60*sampling_rate) & ... 
                                                    QRS_locations <= QRS_locations(a) )), ...
                                       this_iter_QRS_seq_idx, 'UniformOutput', false);

                    aux_featval = cellfun(@(a)(mean(RR_intervals(a))/sampling_rate), aux_idx);
                    featMat_ldc = [ featMat_ldc colvec(log(aux_featval)) ];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % AutoCorr1PlanoWTZeroCross
                    %%%%%%%%%%%%%%%
                    % AutoCorr1PlanoWTModMaxPos
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)( max(1, this_iter_QRS_locations(a) - round(0.08*sampling_rate)): ...
                                             min(this_iter_ECG_resampled_size, this_iter_QRS_locations(a) + round(0.08*sampling_rate))) , ...
                                       this_iter_seq_idx, 'UniformOutput', false);

                    aux_featval = cellfun(@(a)(squeeze(wtECG(a,:,scale_idx(4)))), aux_idx, 'UniformOutput', false);

                    %calculate PCA matrix in this slices for feature
                    %AutoCorr1PlanoWTModMaxPos
                    autovec_slices = cellfun(@(a)(autovec_calculation(a)), aux_featval, 'UniformOutput', false );

                    aux_idx = arrayfun(@(a)( max(1, this_iter_QRS_locations(a) - round(0.13*sampling_rate)): ...
                                             min(this_iter_ECG_resampled_size, this_iter_QRS_locations(a) + round(0.2*sampling_rate))) , ...
                                       this_iter_seq_idx, 'UniformOutput', false);

                    aux_featval = cellfun(@(a,b)(squeeze(wtECG(a,:,scale_idx(4))) * b), aux_idx, autovec_slices, 'UniformOutput', false);
                    [ aux_mp aux_zc ] = cellfun(@(a)(CalcModMaxPos(a(:,1))), aux_featval );

                    featMat_ldc = [ featMat_ldc colvec(aux_zc) colvec(aux_mp) ];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % AutoCorr2PlanoWTZeroCross
                    %%%%%%%%%%%%%%%
                    % AutoCorr2PlanoWTModMaxPos
                    %%%%%%%%%%%%%%%

                    [ aux_mp aux_zc ] = cellfun(@(a)(CalcModMaxPos(a(:,2))), aux_featval );

                    featMat_ldc = [ featMat_ldc colvec(aux_zc) colvec(aux_mp) ];


                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    %clear some auxiliar variables.
                    clear aux*

                    %calculate clustering features.


                    % log(RRactual)
                    %%%%%%%%%%%%%%%
                    featMat_clust = featMat_ldc(:,1);

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(RRant)
                    %%%%%%%%%%%%%%%
                    featMat_clust = [ featMat_clust log(colvec(RR_intervals(max(1, this_iter_QRS_seq_idx-1)))/sampling_rate)];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(Prematuridad_loc)
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)(max(1,a-1):min(cant_QRS_locations,a+1)), this_iter_QRS_seq_idx, 'UniformOutput', false);
                    %tengo que contemplar los casos extremos
                    if( length(aux_idx{1}) < 3 )
                        aux_idx{1} = [1 aux_idx{1}];
                    end
                    if( length(aux_idx{end}) < 3 )
                        aux_idx{end} = [aux_idx{end} cant_QRS_locations];
                    end

                    aux_featval = cellfun(@(a)( RR_intervals(a(2))/sum(RR_intervals(a)) ), aux_idx);
                    featMat_clust = [ featMat_clust colvec(log(aux_featval)) ];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(AbsRRlocalVar)
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)(max(1,a-1):min(cant_QRS_locations,a+1)), this_iter_QRS_seq_idx, 'UniformOutput', false);
                    if( length(aux_idx{1}) < 3 )
                        aux_idx{1} = [1 aux_idx{1}];
                    end
                    if( length(aux_idx{end}) < 3 )
                        aux_idx{end} = [aux_idx{end} cant_QRS_locations];
                    end

                    aux_featval = cellfun(@(a)(SmallValue+sum(abs(dRR_intervals(a)))/sampling_rate), aux_idx);

                    featMat_clust = [ featMat_clust colvec(log(aux_featval)) ];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(RRmean20)
                    %%%%%%%%%%%%%%%

                    featMat_clust = [ featMat_clust featMat_ldc(:,4) ];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % log(QRS_max_scale_proj12)
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)( max(1, this_iter_QRS_locations(a) - round(0.08*sampling_rate)): ...
                                             min(this_iter_ECG_resampled_size, this_iter_QRS_locations(a) + round(0.08*sampling_rate))) , ...
                                       this_iter_seq_idx, 'UniformOutput', false);

                    aux_featval = cellfun(@(a)(wtECG(a,:,:)), aux_idx, 'UniformOutput', false);

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    aux_featval = cellfun(@(a)(squeeze(sum(abs(a(:,1,:))))'), aux_featval, 'UniformOutput', false );
                    aux_featval = cellfun(@(a)(scales * colvec(a) ./ sum(a)), aux_featval );

                %     iAreaAbs = squeeze(sum(abs(wtAux)))';
                %     MaxProjArea = scales * iAreaAbs ./ sum(iAreaAbs);

                    featMat_clust = [ featMat_clust colvec(log(aux_featval)) ];

                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % AutoCorr1PlanoWTModMaxPos
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)( max(1, this_iter_QRS_locations(a) - round(0.13*sampling_rate)): ...
                                             min(this_iter_ECG_resampled_size, this_iter_QRS_locations(a) + round(0.2*sampling_rate))) , ...
                                       this_iter_seq_idx, 'UniformOutput', false);

                    aux_featval = cellfun(@(a,b)(squeeze(wtECG(a,:,scale_idx(4))) * b), aux_idx, autovec_slices, 'UniformOutput', false);
                    aux_featval = cellfun(@(a)(CalcModMaxPos(a(:,1))), aux_featval);

                    featMat_clust = [ featMat_clust colvec(aux_featval) ];


                    % Update point
                    progress_struct = progress_bar(progress_struct);

                    % CrossCorr_QRST_ModMaxVal13
                    %%%%%%%%%%%%%%%

                    aux_idx = arrayfun(@(a)( max(1, this_iter_QRS_locations(a) - round(0.13*sampling_rate)): ...
                                             min( [ this_iter_ECG_resampled_size, ...
                                                    this_iter_QRS_locations(a) + round(0.4*sampling_rate), ...
                                                    this_iter_QRS_locations(a) + RR_intervals(a) - round(0.13*sampling_rate) ] ) ), ...
                                       this_iter_seq_idx, 'UniformOutput', false);


                    if( heasig.nsig > 2 ) 
                        % wtECG already projected in autovec.
                        aux_featval = cellfun(@(a)( CalcModMaxVal( squeeze(wtECG(a,:,scale_idx(3))) ) ), aux_idx);
                    else
                        aux_featval = cellfun(@(a)( CalcModMaxVal( squeeze(wtECG(a,:,scale_idx(3))) * autovec ) ), aux_idx);
                    end

                    featMat_clust = [ featMat_clust colvec(aux_featval) ];

                    %clear some auxiliar variables.
                    clear aux* autovec_slices

            %         if( cant_pids == 1 )
            %             if( cant_iter > 1)
            %                 save([tmp_path 'tmpfile_' rec_filename '_featmatrix_iteration_' num2str(this_iter) '_of_' num2str(cant_iter) ], 'featMat_clust', 'featMat_ldc');
            %             end
            %         else
            %             %multiPIDs, always save
            %             save([tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_thispid_' num2str(this_pid) '_iteration_' num2str(this_iter) '_of_' num2str(cant_iter) ], 'featMat_clust', 'featMat_ldc');
            %         end

                    
                    if( bCache )
                        save([tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_' num2str(this_pid) '_' num2str(this_iter) '_' num2str(cant_iter) '.mat'], 'featMat_clust', 'featMat_ldc');
                        %do this for cluster supercomputers reasons
                    end

                    this_iter_RR_intervals = RR_intervals(this_iter_QRS_seq_idx);
                    %save ECG for user interface and cluster analysis
                    if( bCache )
                        save([tmp_path 'tmpfile_' rec_filename '_ECG_cantpids_' num2str(cant_pids) '_' num2str(this_pid) '_' num2str(this_iter) '_' num2str(cant_iter)  '.mat'], 'ECG', 'this_iter_QRS_locations', 'this_iter_RR_intervals' );
                        %do this for cluster supercomputers reasons
                    end
                    
                    %end of the progress_struct loop 100%
                    progress_struct = progress_bar(100, progress_struct);

                    if( bCache )
                        movefile(   [tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_' num2str(this_pid) '_' num2str(this_iter) '_' num2str(cant_iter)  '.mat'], ...
                                    [tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_thispid_' num2str(this_pid) '_iteration_' num2str(this_iter) '_of_' num2str(cant_iter)  '.mat'], 'f' );

                        movefile(   [tmp_path 'tmpfile_' rec_filename '_ECG_cantpids_' num2str(cant_pids) '_' num2str(this_pid) '_' num2str(this_iter) '_' num2str(cant_iter)  '.mat'], ...
                            [tmp_path 'tmpfile_' rec_filename '_ECG_cantpids_' num2str(cant_pids) '_thispid_' num2str(this_pid) '_iteration_' num2str(this_iter) '_of_' num2str(cant_iter)  '.mat'], 'f' );
                    end
                    
                end

                % Close the loop progress_struct bar.
                progress_bar('off', progress_struct);

                % build datasets from parts.
            %     if( cant_pids == 1 )
            % 
            %         if( cant_iter > 1)
            %             aux_filename = [tmp_path 'tmpfile_' rec_filename '_featmatrix_iteration_' num2str(1) '_of_' num2str(cant_iter) '.mat' ];
            %             load(aux_filename);
            %             delete(aux_filename);
            % 
            %             for this_iter = 2:cant_iter
            %                 aux_filename = [tmp_path 'tmpfile_' rec_filename '_featmatrix_iteration_' num2str(this_iter) '_of_' num2str(cant_iter) '.mat' ];
            %                 aux = load(aux_filename);
            %                 delete(aux_filename);
            %                 featMat_ldc = [featMat_ldc; aux.featMat_ldc];
            %                 featMat_clust = [featMat_clust; aux.featMat_clust];
            %             end
            %         end
            % 
            %     else
            
                %clear some not needed variables 
                clear *ECG this_iter* ann
            
                %multiPIDs. Try to build the whole thing from every parts, otherwise
                %exit.
                if( this_pid ~= cant_pids )
                    %% Slave PIDs
                    % other PIDS sync here after Master build the featmat
                    % file.
                    %last pid
                    bContinue = true;
                    CachedFeatMatFileName = [tmp_path 'tmpfile_' rec_filename '_featmatrix.mat' ];

                    %Wait for Time2WaitPIDs seconds the finalization of all PIDs. Otherwise exit
                    %with error.
                    Start2Wait = tic();

                    while(bContinue)

                        queue2read;

                        try

                            if( exist( CachedFeatMatFileName, 'file') )
                                % restore cached data.
                                load(CachedFeatMatFileName);

                            else
                                error('a2hbc:PIDnotFinished', 'Handled error');
                            end
                            
                            unqueue2read;
                            bContinue = false;

                        catch ME

                            unqueue2read;

                            if( strfind(ME.identifier, 'a2hbc') )
                                if( toc(Start2Wait) > 1.5*Time2WaitPIDs )
                                    error('a2hbc:PIDnotFinished', 'Timeout. Slave give up waitng Master.');
                                end
                                pause(30);
                            else
                                rethrow(ME)
                            end
                        end


                    end

                    
                else
                    %%Master PID
                    %last pid
                    bContinue = true;

                    %Wait for Time2WaitPIDs seconds the finalization of all PIDs. Otherwise exit
                    %with error.
                    Start2Wait = tic();

                    while(bContinue)

                        queue2read;

                        try

                            %auxiliary indexes
                            file_count = 1;
                            File_list = [];
                            File_idx = [];
                            QRS_idx = [];

                            %feature matrices
                            featMat_ldc = [];
                            featMat_clust = [];


                            for ii = 1:cant_pids

                                files_this_pid = dir([tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_thispid_' num2str(ii) '_*.mat' ]);

                                if( isempty(files_this_pid) )
                                    error('a2hbc:PIDnotFinished', 'Handled error');
                                end

                                cant_iteraciones_this_pid = length(files_this_pid);
                                for( jj = 1:cant_iteraciones_this_pid )
                                    aux_FM_filename = [tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_thispid_' num2str(ii) '_iteration_' num2str(jj) '_of_' num2str(cant_iteraciones_this_pid) '.mat' ];
                                    if( ~exist(aux_FM_filename, 'file'))
                                        %Probably this PID not finished yet.
                                        error('a2hbc:PIDnotFinished', 'Handled error');
                                    end
                                    aux_ECG_filename = ['tmpfile_' rec_filename '_ECG_cantpids_' num2str(cant_pids) '_thispid_' num2str(ii) '_iteration_' num2str(jj) '_of_' num2str(cant_iteraciones_this_pid) '.mat' ];
                                    aux_ECG_fullpath = [tmp_path aux_ECG_filename ];
                                    if( ~exist(aux_ECG_fullpath, 'file'))
                                        %Probably this PID not finished yet.
                                        error('a2hbc:PIDnotFinished', 'Handled error');
                                    end
                                    aux = load(aux_FM_filename);
                                    featMat_ldc = [featMat_ldc; aux.featMat_ldc];
                                    featMat_clust = [featMat_clust; aux.featMat_clust];

                                    aux = load(aux_ECG_fullpath, 'this_iter_QRS_locations');
                                    cant_QRS = length(aux.this_iter_QRS_locations);
                                    QRS_idx = [QRS_idx; uint16(colvec(1:cant_QRS))];
                                    File_idx = [File_idx; repmat(uint16(file_count), cant_QRS, 1)];
                                    File_list = [File_list; cellstr(aux_ECG_filename)];
                                    file_count = file_count + 1;
                                end

                            end
                            
                            unqueue2read;
                            bContinue = false;

                        catch ME

                            unqueue2read;

                            if( strfind(ME.identifier, 'a2hbc') )
                                if( toc(Start2Wait) > Time2WaitPIDs )
                                    error('a2hbc:PIDnotFinished', 'Timeout. Master give up waitng Slaves.');
                                end
                                pause(30);
                            else
                                rethrow(ME)
                            end
                        end


                    end
                    
                    if( bCache )
                        %Cache the datasets for future executions.
                        save([tmp_path 'tmpfile_' rec_filename '_featmatrix_tmp.mat' ], 'featMat_clust', 'featMat_ldc', 'QRS_idx', 'File_idx', 'File_list');
                        movefile(   [tmp_path 'tmpfile_' rec_filename '_featmatrix_tmp.mat' ], ...
                                    [tmp_path 'tmpfile_' rec_filename '_featmatrix.mat' ], 'f' );
                    end

                    for ii = 1:cant_pids
                        %If evth goes well, delete temp files
                        for( jj = 1:cant_iteraciones_this_pid )
                            aux_FM_filename = [tmp_path 'tmpfile_' rec_filename '_featmatrix_cantpids_' num2str(cant_pids) '_thispid_' num2str(ii) '_iteration_' num2str(jj) '_of_' num2str(cant_iteraciones_this_pid) '.mat' ];
                            %delete FM parts
                            delete(aux_FM_filename);
                        end
                    end
                    
                end

            %     end

                % Activate again the progress_struct bar.
                progress_struct = progress_bar('on', ['Processing ' rec_filename ' recording' ]);
                position_waitbar;
                
                %start of the progress_struct loop 0%
                progress_struct = progress_bar(0, progress_struct);

                %clear some not needed variables 
                clear aux
                
            end

            %% Feature Matrices building

            % Update point
            progress_struct = progress_bar(progress_struct, 'Clean featureMatrix from NAN values');

            %clean featureMatrix from NAN values.
            AnyNaN_idx = find(any(isnan(featMat_clust),2));
            iAllMedian = nanmedian(featMat_clust);
            if(any(isnan(iAllMedian)))
               error( 'a2hbc:AllNanFeatures', 'Features not calculated in this recording. Check recording or ask help.\n' );
            end
            for ii = rowvec(AnyNaN_idx)
               bIdx2 = find(isnan(featMat_clust(ii,:)));
               featMat_clust(ii, bIdx2) = iAllMedian(bIdx2);
            end

            AnyNaN_idx = find(any(isnan(featMat_ldc),2));
            iAllMedian = nanmedian(featMat_ldc);
            if(any(isnan(iAllMedian)))
               error( 'a2hbc:AllNanFeatures', 'Features not calculated in this recording. Check recording or ask help.\n' );
            end
            for ii = rowvec(AnyNaN_idx)
               bIdx2 = find(isnan(featMat_ldc(ii,:)));
               featMat_ldc(ii, bIdx2) = iAllMedian(bIdx2);
            end

            % por el momento sigo usando el PRtools.
            % armo datasets.
            featMat_clust = dataset(featMat_clust);
            featMat_ldc = dataset(featMat_ldc);


            if( bHaveUserInterface && (~exist('UCP_struct', 'var') || ~ishandle(UCP_struct.fig_hdl)) )
                UserControlPanel;
                ParseUserControlPanelInput;
            end

        end

        %% Classification

        already_labeled_idx = [];
        pending_hb_idx = setdiff((1:cant_QRS_locations)', already_labeled_idx );
        bCancel = false;
        
        bVerbose = true;
        if( bVerbose )
            DisplayConfiguration;
        end
        
        while( ~bCancel && ~isempty(pending_hb_idx) )

            bDataSkiped = false;
            this_loop_already_labeled_idx = [];
            this_loop_cant_pending = length(pending_hb_idx);

            % Update point
            progress_struct = progress_bar(progress_struct, 'Clustering data.');

            %skip warnings here
            warning off all; prwarning(0);
            Clust_Labels = cluster_data_with_EM_clust(featMat_clust(pending_hb_idx,:), qdc_new([],1e-6,1e-6, []), CantClusters, iter_times);
            warning on all; prwarning(1);

            [~, sort_idx] = sort( Clust_Labels );
            [all_clusters, aux_location] = unique(Clust_Labels(sort_idx,:), 'first');

            aux_location = [colvec(aux_location); cant_QRS_locations+1];
            cluster_sizes = diff(aux_location);
            cant_clusters = size(all_clusters,1);

            if( bHaveUserInterface)
                set(UCP_struct.Axes_hdl, 'Visible','on' );
%                 waitbar(0, UCP_struct.fig_hdl, 'Classification progress 0%')
                hb_percent_done = (length(already_labeled_idx) + length(this_loop_already_labeled_idx))/cant_QRS_locations;
                waitbar( hb_percent_done, UCP_struct.fig_hdl, [ 'Classification progress ' num2str(round(hb_percent_done*100)) '%' ])
            end
            
            %% Intento de clasificacion autom�tica.
            % Aqu� trabaja el GC.

            % Update point
            progress_struct = progress_bar(progress_struct, 'Automatic classification');


            if( strcmpi(op_mode, 'slightly-assisted') || strcmpi(op_mode, 'auto') )

                dsThisPatient_classification = featMat_ldc * global_classifier;

                dsThisPatient_classification = labeld(dsThisPatient_classification);
                dsThisPatient_classification = renumlab(dsThisPatient_classification, typical_lablist); % try to fit on original lablist

                for ii = 1:cant_clusters

                    %los latidos de este cluster
                    aux_idx = sort_idx(aux_location(ii):(aux_location(ii+1)-1));

                    %busco las clasificaciones no rechazadas.
                    aux_idx1 = find(dsThisPatient_classification(aux_idx) ~= 0);

                    cantXclase = histc( dsThisPatient_classification(aux_idx(aux_idx1)), 1:typical_cant_labels );

                    %busco la clase mas predecida
                    [~, class_idx] = max(cantXclase);

                    if( cantXclase(class_idx) > ( cluster_presence  * 0.01 * cluster_sizes(ii) ) )
                        % La mayoria impone su clase.
                        Clust_Labels(aux_idx) = class_idx;
                        
                        this_loop_already_labeled_idx = [ this_loop_already_labeled_idx; colvec(aux_idx) ];

                        if( bHaveUserInterface)                            
                            hb_percent_done = (length(already_labeled_idx) + length(this_loop_already_labeled_idx))/cant_QRS_locations;
                            waitbar( hb_percent_done, UCP_struct.fig_hdl, [ 'Classification progress ' num2str(round(hb_percent_done*100)) '%' ])
                        end
                        
                    else
                        %for the slightly assisted, in the next section the
                        %expert will do the labeling.
                        if( strcmpi(op_mode, 'auto') )
                            %se deja la clasificacion autom�tica.
                            Clust_Labels(aux_idx) = dsThisPatient_classification(aux_idx);
                            
                            this_loop_already_labeled_idx = [ this_loop_already_labeled_idx; colvec(aux_idx) ];

                            if( bHaveUserInterface)                            
                                hb_percent_done = (length(already_labeled_idx) + length(this_loop_already_labeled_idx))/cant_QRS_locations;
                                waitbar( hb_percent_done, UCP_struct.fig_hdl, [ 'Classification progress ' num2str(round(hb_percent_done*100)) '%' ])
                            end                                
                            
                        end
                    end
                end                    
            end

            %% Clasificacion manual.
            % Aca consultamos al ORACLE.

            % Update point
            progress_struct = progress_bar(progress_struct, 'Expert assistance');

            if( any(strcmpi(op_mode, {'assisted' 'slightly-assisted'}) ) )
                %Clustering + global classifier (GC) + oracle
                %Clustering + oracle
                %busco los centroides o algun elemento
                %representativo de cada cluster
                not_labeled_idx = setdiff(1:this_loop_cant_pending, this_loop_already_labeled_idx );
                [~, sort_idx] = sort( Clust_Labels(not_labeled_idx) );
                [all_clusters, aux_location] = unique(Clust_Labels(not_labeled_idx(sort_idx)), 'first');

                m_not_labeled = length(not_labeled_idx);

                aux_location = [colvec(aux_location); m_not_labeled+1];
                cluster_sizes = diff(aux_location);
                cant_clusters = size(all_clusters,1);

                ii = 1;
                while( ii <= cant_clusters )

                    %los latidos de este cluster
                    aux_idx = sort_idx(aux_location(ii):(aux_location(ii+1)-1));

                    %si es muy grande lo sampleo uniformemente para
                    %no generar mucho costo computacional.
                    laux_idx = length(aux_idx);
                    if( laux_idx > 5000 )
                        aux_idx2 = randsample(laux_idx, 5000);
                    else
                        aux_idx2 = 1:laux_idx;
                    end

                    %busco el centroide del cluster para
                    %etuiquetarlo.
                    clust_data_m = length(aux_idx2);
                    
                    if( clust_data_m > 1 )
                        
                        clust_data = [ featMat_clust(pending_hb_idx(not_labeled_idx(aux_idx(aux_idx2))),:); featMat_clust(pending_hb_idx(not_labeled_idx(aux_idx(aux_idx2))),:) ];
                        clust_data = setlabels(clust_data,[ones(clust_data_m,1);2*ones(clust_data_m,1)] );
                        clust_data = setprior(clust_data,[1 1]./2 );
                        clust_data_model = qdc(clust_data, 1e-6, 1e-6);
                        clust_data_posterior = clust_data * clust_data_model;
                        clust_dist2mu = +clust_data_posterior(1:clust_data_m,1);

                        [~, clust_dist2mu_sorted_idx ] = sort(clust_dist2mu, 'descend');

                    else
                        clust_dist2mu_sorted_idx = 1;
                    end
                    
                    if( ~bHaveUserInterface || bSimulateExpert )

                        clust_sample_centroid_idx = clust_dist2mu_sorted_idx(1);
                        %a cada cluster le asignamos la etiqueta
                        %VERDADERA del elemento mas cercano al centroide.
                        Clust_Labels(not_labeled_idx(aux_idx)) = true_labels(not_labeled_idx(aux_idx(aux_idx2(clust_sample_centroid_idx))));
                        
                        this_loop_already_labeled_idx = [ this_loop_already_labeled_idx; colvec(not_labeled_idx(aux_idx)) ];

                        if( bHaveUserInterface )
                            hb_percent_done = (length(already_labeled_idx) + length(this_loop_already_labeled_idx))/cant_QRS_locations;
                            waitbar( hb_percent_done, UCP_struct.fig_hdl, [ 'Classification progress ' num2str(round(hb_percent_done*100)) '%' ])
                        end
                        
                        ii = ii + 1;
                        
                    else
                        clust_sample_centroid_idx = clust_dist2mu_sorted_idx(1);
                        fprintf(1, ['Suggestion: ' typical_lablist(true_labels(not_labeled_idx(aux_idx(aux_idx2(clust_sample_centroid_idx)))),:) '\n']);
                        
                        %find heartbeat samples to show to the expert.
                        FindClusterExamples;

                        % Ask for expert opinion
                        [ Label bRefresh bCancel ] = ExpertUserInterface(cCentroid, cCloserExamples, cDistantExamples);

                        if(bCancel)
                            fprintf(2, 'Canceling current classification.\n');
                            if( bHaveUserInterface )                            
                                if( ishandle(UCP_struct.fig_hdl) )
                                    waitbar(0, UCP_struct.fig_hdl, 'Classification progress 0%')
                                    set(UCP_struct.Axes_hdl, 'Visible','off' );
                                end
                            end
                            break;
                        end

                        if( ~bRefresh  )

                            if( isempty(Label) )
                                bDataSkiped = true;
                                disp(['Skipping ' num2str(clust_data_m) ' heartbeats to re-cluster.'])
                            else
                                Clust_Labels(not_labeled_idx(aux_idx)) = find( strcmpi(cellstr(typical_lablist), Label) );
                                this_loop_already_labeled_idx = [ this_loop_already_labeled_idx; colvec(not_labeled_idx(aux_idx)) ];

                                hb_percent_done = (length(already_labeled_idx) + length(this_loop_already_labeled_idx))/cant_QRS_locations;
                                waitbar( hb_percent_done, UCP_struct.fig_hdl, [ 'Classification progress ' num2str(round(hb_percent_done*100)) '%' ])
                            end
                            ii = ii + 1;
                        end
                    end
                end
            end

            if( ~bCancel )

                %save the labeling done
                Labels(pending_hb_idx) = Clust_Labels;
                already_labeled_idx = [already_labeled_idx; colvec(pending_hb_idx(this_loop_already_labeled_idx))];
                pending_hb_idx = setdiff(1:cant_QRS_locations, already_labeled_idx );

                if(bHaveUserInterface)
                    if( bDataSkiped  )
                        %Maybe some fine tuning is necesary ...
                        if( ~exist('UCP_struct', 'var') || ~ishandle(UCP_struct.fig_hdl) )
                            UserControlPanel;
                        end

                        cant_hb_pending = length(pending_hb_idx);
                        fprintf(1, [num2str(cant_hb_pending) ' heartbeats remaining. Any fine tuning needed ? Change controls freely\n' ] );

                        if( cant_hb_pending < 90 ) % 10 * (k+1) * clusters
                            recommended_clusters = max(2, round(cant_hb_pending/90));
                            fprintf(2, [ 'Too few heartbeats. Recommended clusters: '  num2str(recommended_clusters) ]);
                            set(UCP_struct.CantClusters, 'Value', recommended_clusters);
                        end
                        
%                         set(UCP_struct.fig_hdl, 'Visible','on' );
                        EnableControPanel;

                        uiwait(UCP_struct.fig_hdl);
                        
                        if( ishandle(UCP_struct.fig_hdl) )
                            DisableControPanel;
%                             set(UCP_struct.fig_hdl, 'Visible','off' );
                        else
                            bCancel = true;
                            fprintf(2, 'Canceling current classification.\n');
                        end
                    end

                    %to update current user interaction.
                    ParseUserControlPanelInput;
                end
                
            end

        end

        %% Results generation

        if( bCancel )
            %Cancelation of expert input ends here.
            bCancel = false;
        else

            % Update point
            progress_struct = progress_bar(progress_struct, 'Results generation');

            if( ~isempty(true_labels) )
                [~, this_iter_cm] = DisplayResults('TrueLabels', typical_lablist(true_labels,:), 'ClassifiedLabels', typical_lablist(Labels,:), 'ClassLabels', typical_lablist);
            else
                %not possible to build a confusion matrix without the true labels.
                this_iter_cm = nan(typical_cant_labels);
            end   
        end

        % All done
        if( bHaveUserInterface )
            if( ishandle(progress_struct.handle) )
                waitbar(1, progress_struct.handle, 'Work done');
            end
        end
        
    catch MException
        %% Error handling

        if( bHaveUserInterface)
            %% with UI
            if( ~isempty(strfind(MException.identifier, 'a2hbc')) || isempty(MException.identifier) )
                %Our errors
                if( strfind(MException.identifier, 'ArgCheck') )
                    %Argument error, try other settings if user interface is
                    %available
                    fprintf(2, '%s', MException.message);
                    fprintf(2, '\nTry a different set of arguments with the user interface.\n');
                else
                    if( isempty(MException.identifier) )
                        %User break with CTRL-C ??
                        fprintf(2, '\nUser interruption.\n');
                    else
                        %other home-made errors. Make an educated exit ...
                        rethrow(MException)
                    end
                end

            else
                %% Other unknown errors -> Report it to me

                if( strcmpi( 'Yes', questdlg('Oh no! An unexpected error ocurred. Please take a minute to report it so I can fix it and improve A2HBC. Report error information through Internet ?', 'Unhandled error', 'Yes', 'No', 'Yes')) )
                    %report an error
                    if( ~exist('progress_struct', 'var') )
                        progress_struct = progress_bar('on', ['Processing ' rec_filename ' recording' ]);
                        %start of the progress_struct loop 0%
                        progress_struct = progress_bar(0, progress_struct);
                    end
                    progress_struct = progress_bar(progress_struct, 'Saving error report');

                    timestamp = datestr(now, 'HH-MM-SS_dd-mm-yy');
                    report_filename = [tmp_path 'error_report_' timestamp '_' rec_filename '.mat' ];

                    %clean heavy variables
                    variables = whos();
                    [var_size, var_idx] = sort(cell2mat({variables(:).bytes}));
                    cum_var_size = cumsum(var_size);
                    last_var_idx = find( (cum_var_size/typical_compression_ratio) <= max_report_filesize, 1, 'last');
                    %save does not accept cell arrays as input -> workaround
                    var_names = {variables(var_idx(1:last_var_idx)).name};
                    feval( @save, report_filename, var_names{:} )

                    progress_struct = progress_bar(progress_struct, 'Compressing');
                    report_filename_gz = gzip( report_filename );
                    delete( report_filename );

                    progress_struct = progress_bar(progress_struct, 'Reporting');

                    setpref('Internet','E_mail', 'a2hbc.errors@gmail.com');
                    setpref('Internet','SMTP_Server','smtp.gmail.com');
                    setpref('Internet','SMTP_Username','a2hbc.errors');
                    setpref('Internet','SMTP_Password', 'Any_password');
                    props = java.lang.System.getProperties;
                    props.setProperty('mail.smtp.auth','true');
                    props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
                    props.setProperty('mail.smtp.socketFactory.port','465');   

%                     local_host = 'unknown';
%                     ip_address = 'unknown';
%                     location = 'unknown';
                    
                    %just to identify reports
                    local_host = java.net.InetAddress.getLocalHost;
                    
                    try
                        ip_address = urlread('http://automation.whatismyip.com/n09230945.asp');
                    catch dummyME
                        ip_address = '';
                    end
    
                    try
                        location = urlread('http://www.ipaddresslocation.org/my-ip-address.php');
                    catch dummyME
                        location = '';
                    end

                    computer_arch = computer();
                    computer_installation = ver();
                    lcomputer_installation = length(computer_installation);
                    tab_aux = cellstr(repmat('\t\t', lcomputer_installation, 1));
                    crlf_aux = repmat('\n', lcomputer_installation, 1);
                    computer_installation = strcat( colvec({computer_installation(:).Name}), tab_aux, colvec({computer_installation(:).Version}), tab_aux, colvec({computer_installation(:).Release}) );
                    computer_installation = [char(computer_installation) crlf_aux];
                    computer_installation = cellstr(sprintf(colvec(computer_installation')));

                    sendmail({'llamedom@unizar.es' 'llamedom@electron.frba.utn.edu.ar'}, ... %recipients
                            ['[A2HBC Error reporting] ' char(local_host)], ... %subject
                            [ cellstr(location) ; cellstr(ip_address) ; cellstr(computer_arch) ; computer_installation], ... %body
                            report_filename_gz); %attach

                    progress_struct = progress_bar(progress_struct, 'Report sent successfully');

                    delete( char(report_filename_gz) );
                    
                    fprintf(1, '\n------------------------\nReport sent successfully\n------------------------\n\nThis is the error information:\n\n');
                    
                else                
                    %try to convince user for the next time.
                    fprintf( 2, '\nOk, thank you anyway. Please consider sending a report in case this error happens again.\n\n')
                end

                rethrow(MException);
            end
        else
            %% No User interface
            fprintf(2,'\n\n')
            fprintf(2,'###########\n')
            fprintf(2,'## ERROR ##\n')
            fprintf(2,'###########\n')

            fprintf(2,'Recording: %s (%d/%d) \n', recording_name, this_pid, cant_pids);

            strAux = GetFunctionInvocation(mfilename, varargin);
            
            local_host = getenv('HOSTNAME');
            computer_arch = computer();

            fprintf(2,'Computer: %s (%s) \n', local_host, computer_arch);
            
            fprintf(2, '%s\n\n', strAux);
            
            report = getReport(MException);
            fprintf(2, '%s', report);
            fprintf(2,'###########\n')
            fprintf(2,'## ERROR ##\n')
            fprintf(2,'###########\n')
            
            rethrow(MException)

        end
        

    end

    ConfusionMatrix(:,:,repeat_idx) = this_iter_cm;
    
    if( bHaveUserInterface && ( ~bArgCheckPassed || bInteractiveMode ) )
        %% Ask User interaction
        % only if: the arguments were incorrect or I want to use a2hbc
        % in interactive mode.
        
        UserInteraction;

    else
        %If not user interface available -> unatended mode, just exit the loop.
        %bUserExit = true;
        repeat_idx = repeat_idx + 1;
    end

end

LabelList = typical_lablist;

%save results when running without user interface.
if( ~bHaveUserInterface )
    
    save([tmp_path 'tmpfile_' rec_filename '_results_' op_mode '_' num2str(CantClusters) '_' num2str(iter_times) '_' num2str(cluster_presence) '_' num2str(this_pid) '.mat' ], 'Labels', 'ConfusionMatrix', 'LabelList');
    
    % flag that the program ended correctly
    setenv('A2HBC_ES', '0');
end


%%%%%%%%%%%%%%%%%%
% Other functions
%%%%%%%%%%%%%%%%%%

function autovec = autovec_calculation(wtECGslice)

    mean_wtECGslice = mean(wtECGslice);    
    wtECGslice_cov = cov( bsxfun( @minus, wtECGslice, mean_wtECGslice ));
    [autovec autoval] = eig(wtECGslice_cov); 
    [~, autoval_idx] = sort(diag(autoval), 'descend');
    autovec = autovec(:,autoval_idx);
    
function [ ModMaxPos ZeroCross ] = CalcModMaxPos( wtSignal )

ModMaxPos = nan;
ZeroCross = nan;

lwtSignal = size(wtSignal, 1);

if( all( wtSignal == 0 ) )
    return
end

ac1 = conv(wtSignal(:,1), flipud(wtSignal(:,1)));

ac1 = ac1(lwtSignal:end);
ac1 = 1/ac1(1)*ac1;

interp_idx = (1:0.1:lwtSignal)';

ac1_interp = spline( 1:lwtSignal, ac1, interp_idx );
iZeroCrossPos_ac1 = myzerocros(ac1);

if( isempty(iZeroCrossPos_ac1))
    return
else
    if( iZeroCrossPos_ac1(1) < lwtSignal )
        if( sign(ac1(iZeroCrossPos_ac1(1))) ~= sign(ac1(iZeroCrossPos_ac1(1)+1)) )
            ZeroCross = iZeroCrossPos_ac1(1) - ac1(iZeroCrossPos_ac1(1)) / ( ac1(iZeroCrossPos_ac1(1)+1) - ac1(iZeroCrossPos_ac1(1)) );
        else
            ZeroCross = (iZeroCrossPos_ac1(1)-1) - ac1(iZeroCrossPos_ac1(1)-1) / ( ac1(iZeroCrossPos_ac1(1)) - ac1(iZeroCrossPos_ac1(1)-1) );
        end
    else
        return
    end   
end

ModMaxPos_ac1 = modmax( ac1_interp, 2, 0, 0 );

if( ~isempty(ModMaxPos_ac1) )
    valid_ac1_max_idx = find(interp_idx(ModMaxPos_ac1) > ZeroCross);
    if( ~isempty(valid_ac1_max_idx) )
        ModMaxPos = interp_idx(ModMaxPos_ac1(valid_ac1_max_idx(1)));
    else
        return
    end
else
    return
end

function ModMaxVal = CalcModMaxVal( wtSignal )

% std_wtSignal = std(wtSignal);
% wtSignal = bsxfun( @times, wtSignal, 1./std_wtSignal);

cc = conv(wtSignal(:,1), flipud(wtSignal(:,2)));

[~, max_pos] = max(abs(cc));

ModMaxVal = cc(max_pos);

function posterior = CalcLDCposterior(data, ldc_struct)

[ cant_classes k ] = size(ldc_struct.mean);

posterior = nan(size(data,1), cant_classes);

for ii = 1:cant_classes
    
    centered_data = bsxfun( @minus, data, ldc_struct.mean(ii,:));

    posterior(:,ii) = exp(-0.5*sum(centered_data'.*(ldc_struct.cov(:,:,ii)*centered_data'),1)' - (ldc_struct.det(ii) + k*log(2*pi))*0.5);

end

function RunNow(obj, event_obj)

fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
uiresume(fig_hnd); 

function SliderFunc(obj, event_obj)
fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
NewVal = round(get(obj , 'Value'));
set(obj , 'Value', NewVal );
set(user_data.SliderLabel , 'String', [ num2str(NewVal) ' Clusters'] );

function SliderFunc2(obj, event_obj)
fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
NewVal = round(get(obj , 'Value'));
set(obj , 'Value', NewVal );
strAux = [ num2str(NewVal) ' repetition'];
if(NewVal > 1)
    strAux= [strAux 's'];
end
set(user_data.SliderLabel2 , 'String', strAux );

function SliderFunc3(obj, event_obj)
fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
NewVal = round(get(obj , 'Value'));
set(obj , 'Value', NewVal );
set(user_data.SliderLabel3 , 'String', [ 'Cluster majority ' num2str(NewVal) ' %'] );

function OpModeSelect(obj, event_obj)
fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
Selection = get(obj , 'Value');

if( Selection > 2 )
    set(user_data.cluster_presence , 'Enable', 'off' );
else
    set(user_data.cluster_presence , 'Enable', 'on' );
end

function FormatCheck(obj, event_obj)
fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
NewVal = round(get(obj , 'Value'));
set(obj , 'Value', NewVal );
set(user_data.SliderLabel3 , 'String', [ 'Cluster majority ' num2str(NewVal) ' %'] );

function BrowseRecording(obj, event_obj)
fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
recording_name = get(user_data.recording_name , 'String');
[recording_path, ~, recording_ext] = fileparts(recording_name);
[recording_name, recording_path] = uigetfile([recording_path filesep '*.*'], 'Select a recording');
if( recording_name ~= 0 )
    set(user_data.recording_name , 'String', [ recording_path recording_name]);
end

function BrowseTMPpath(obj, event_obj)
fig_hnd = gcf();
user_data = get(fig_hnd , 'User');
tmp_path = get(user_data.tmp_path , 'String');
tmp_path = uigetdir(tmp_path, 'Select temporal directory');
if( tmp_path ~= 0 )
    set(user_data.tmp_path , 'String', tmp_path);
end

function PathCheck(obj, event_obj)

tmp_path = get(obj , 'String');

if( exist( tmp_path, 'dir' ) )
    set(obj , 'String', tmp_path)
    set(obj , 'Tag', tmp_path)
else
    fprintf(2, ['Path not found. ' tmp_path '\n'] )
    set(obj , 'String', get(obj , 'Tag') )
end

function RecordingCheck(obj, event_obj)

recording = get(obj , 'String');

if( exist( recording, 'file' ) )
    set(obj , 'String', recording)
    set(obj , 'Tag', recording)
else
    fprintf(2, ['File not found. ' recording '\n'] )
    set(obj , 'String', get(obj , 'Tag') )
end

function CheckNumeric(obj, event_obj)

number = get(obj , 'String');

if( isnan(str2double(number)) )
    fprintf(2, ['Not a valid numeric value: ' number '\n'] )
    set(obj , 'String', get(obj , 'Tag') )
else
    set(obj , 'String', number)
    set(obj , 'Tag', number)
end

