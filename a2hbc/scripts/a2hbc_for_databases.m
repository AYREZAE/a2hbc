function a2hbc_for_databases(DBname, varargin)

% Argentino-Aragonés heartbeat classifier (a2hbc) parser for public databases (for Matlab)
% ---------------------------------------------------------------------------------------
% 
% Description:
% 
% Performs ECG heartbeat classification in the input ECG signal in one of the following modes:
% 1. Automatic or Unassisted (default).
% 2. Slightly assisted. Ask minimum user assistance for cluster decision.
% 3. Fully assisted. Ask a decision for each cluster detected.
% 
% The classification is performed among the three AAMI classes: normal
% beats (N), supraventricular (S) and Ventricular (V).
% 
% Arguments: (specified as a2hbc('arg_name1', arg_val1, ... , 'arg_nameN', arg_valN) )
% 
%     a. ECG specification:
% 
%         a.1 Recording filename where ECG is stored in a valid format.
% 
%           + recording_name: ECG recording to be classified.
%           + recording_format : Valid ECG format. (MIT, ISHNE, AHA, HES)
% 
%         a.2 ECG signal/s ADC samples, header and QRS locations. Useful if 
%             you plan to hook this software in your code.
% 
%           + ECG: ECG signal matrix. Columns are leads.
%           + ECG_header: Description of the ECG typically available in the
%                         header. Structure with fields:
%           + QRS_locations: QRS locations of the ECG. Typically available in the
%                      "time" field of the annotations. 
% 
%     b. Operating modes
%         + op_mode: Operating mode 1 (default), 2 or 3; for the modes
%                    described above.
% 
%     c. Modifiers
% 
%       c.1 Multiprocess modifiers:
%         + cant_pids: Number of processes to divide the work. Each process
%                      will work in a 1/cant_pids part of the ECG.
%         + this_pid: Identifies each process with an integer between
%                     1 - cant_pids.
% 
%       c.2 Other modifiers:
%         + :
% 
% Output:
%   + Labels: Classification Labels for each QRS location provided.
% 
% References:
% 
% [1] Llamedo, M. Martínez, J. Heartbeat Classification Using Feature
%     Selection driven by Database Generalization Criteria IEEE
%     Transactions on Biomedical Engineering, 2011, 58, 616-625
% [2] Under review
% [3] Under review
% 
% Limits and Known bugs:
% 
% How to cite:
% If you found this software useful, you may  be interested in reading these articles:
% 
% [1] Llamedo, M. Martínez, J. Heartbeat Classification Using Feature Selection driven by Database Generalization Criteria IEEE Transactions on Biomedical Engineering, 2011, 58, 616-625
% @ARTICLE{Llamedo11, author = {Llamedo, M. and Martínez, J.P.}, title = {Heartbeat Classification Using Feature Selection driven by Database Generalization Criteria}, journal = {IEEE Transactions on Biomedical Engineering}, year = {2011}, volume = {58}, pages = {616-625} }
% 
% Author: Mariano Llamedo Soria (llamedom at {electron.frba.utn.edu.ar; unizar.es}
% Birthdate  : 16/8/2011
% Last update: 25/8/2011

%% Constants and definitions

a2hbc_for_databases_header;

%% Argument parsing
    
p = inputParser;   % Create instance of inputParser class.

p.addRequired('DBname', @(x)(ischar(x) || iscellstr(x) ) );
p.addParamValue('recording_indexes', [], @(x)(all(isnumeric(x)) && all(x > 0) ) );
p.addParamValue('DB_format', [], @(x)( isempty(x) | any(strcmpi(x,cKnownFormats))) );
p.addParamValue('op_mode', 'auto', @(x)( (isnumeric(x) && x >= 1  && x <= maxOperMode) || any(strcmpi(x,cKnownModesOfOperation))) );
p.addParamValue('cant_pids', 1, @(x)(isnumeric(x) && x > 0 ) );
p.addParamValue('this_pid', 1, @(x)(isnumeric(x) && x > 0 ) );
p.addParamValue('tmp_path', [], @(x)(ischar(tmp_path) ) );

try
    p.parse( DBname, varargin{:});
catch MyError
    rethrow(MyError);    
end

recording_indexes = p.Results.recording_indexes;
format = p.Results.DB_format;
cant_pids = p.Results.cant_pids;
this_pid = p.Results.this_pid;
op_mode = p.Results.op_mode;

clear p

% check DBname

[DBname, DBname_idx] = intersect(DB_info(:,ShortName_idx), cellstr(DBname));
    
if(isempty(DBname))
   error( 'a2hbc_fdb:ArgCheck:InvalidDBname', 'Please provide a valid database name.\n' );
end

if( this_pid > cant_pids)
    return;
end

if( isempty(tmp_path) )
    tmp_path = [fileparts(mfilename('fullpath')) filesep 'tmp' filesep ];
end

if( isnumeric(op_mode) )
    op_mode = cKnownModesOfOperation{op_mode};
end


for DB_idx = rowvec(DBname_idx)

    fprintf(1, [ '\n' DB_info{DB_idx,ShortName_idx} '\n' ]);
    fprintf(1, [ repmat('-',1, length(DB_info{DB_idx,ShortName_idx})) '\n' ]);
    
    %build tmp path
    thisDB_tmp_path = [tmp_path DB_info{DB_idx,ShortName_idx} filesep ];
    if( ~exist(thisDB_tmp_path, 'dir') )
        if( ~mkdir(thisDB_tmp_path) )
            error('a2hbc_fdb:tmp_path', 'Invalid tmp_path. Could not create it.\n' );
        end
    end

    %check database recordings
    
    bDBfound = false;
    for each_dbpath = rowvec(databases_paths)
        thisDB_rec_path = [ each_dbpath{1} DB_info{DB_idx,ShortName_idx} filesep];
        thisDB_rec_files = dir( [thisDB_rec_path '*.' DB_info{DB_idx,RecExtension_idx} ]);
        lthisDB_rec_files = length(thisDB_rec_files);
        if( lthisDB_rec_files == DB_info{DB_idx,CantRecordings_idx} )
            bDBfound = true;
            break
        end
    end
    if( ~bDBfound )
        error('a2hbc_fdb:DBnot_found', 'DB not found.\n' );
    end

    for rec_idx = rowvec(recording_indexes)
        
        [ ~, ConfusionMatrix ] = a2hbc(  ...
                                        'recording_name', [thisDB_rec_path thisDB_rec_files(rec_idx).name], ...
                                        'recording_format', DB_info{DB_idx,Format_idx}, ...
                                        'op_mode', op_mode, ...
                                        'tmp_path', thisDB_tmp_path, ...
                                        'this_pid', this_pid, ...
                                        'cant_pids', cant_pids ...
                                      );
    end
    
end

