function [ECG heasig ann] = read_ECG(recording_name, recording_format, ECG_start_idx, ECG_end_idx)

ECG = [];
heasig = [];
ann = [];

if( nargin < 3 )
    ECG_start_idx = [];
end

if( nargin < 4 )
    ECG_end_idx = [];
end

if( strcmp(recording_format, 'ISHNE') )
    if( nargout > 1 )
        [ECG heasig ann] = read_ishne(recording_name, ECG_start_idx, ECG_end_idx );
    else
        ECG = read_ishne(recording_name, ECG_start_idx, ECG_end_idx );
    end        
elseif( strcmp(recording_format, 'MAT') )
    
    aux_load = load(recording_name);

    if( nargout > 1 )
        ann = aux_load.ann;
        ECG = aux_load.ECG;
        heasig = aux_load.heasig;
    else
        ECG = aux_load.ECG;
    end
    clear aux_load
    
elseif( strcmp(recording_format, 'AHA') )
    if( nargout > 1 )
        [ECG heasig ann] = read_AHA_format(recording_name, ECG_start_idx, ECG_end_idx );
    else
        ECG = read_AHA_format(recording_name, ECG_start_idx, ECG_end_idx );
    end
elseif( strcmp(recording_format, 'HES') )
    if( nargout > 1 )
        [ECG heasig ann] = read_HES_format(recording_name, ECG_start_idx, ECG_end_idx );
    else
        ECG = read_HES_format(recording_name, ECG_start_idx, ECG_end_idx );
    end
elseif( strcmp(recording_format, 'MIT') )
    %% MIT various data formats

    if( nargout > 2 )
        strAnnExtension = {'ari' 'atr' 'ecg'};
        bAnnotationFound = false;
        for ii = 1:length(strAnnExtension)
            annFileName = [recording_name(1:end-3) strAnnExtension{ii}];
            if( exist(annFileName, 'file') )
                bAnnotationFound = true;
                break
            end
        end
        if(~bAnnotationFound)
            error( 'read_ECG:AnnNotFound', ['Can�t find annotations for file : ' rowvec(recording_name') ] );
        end

        ann = readannot(annFileName);
    end
    
    heasig = readheader([recording_name(1:end-3) 'hea']);    
    
    recording_files = unique(cellstr(heasig.fname));
    recording_path = [fileparts(recording_name) filesep];

    if( isempty( ECG_start_idx ) )
        ECG_start_idx = 1;
    else
        ECG_start_idx = max(1,ECG_start_idx);
    end

    if( isempty( ECG_end_idx ) )
        %Intento la lectura total por defecto
        ECG_end_idx = heasig.nsamp;
    else
        ECG_end_idx = min(heasig.nsamp, ECG_end_idx);
    end
    
    for ii = 1:length(recording_files)
        sig_idx = find(strcmpi(recording_files(ii), cellstr(heasig.fname)));
        nsig = length(sig_idx);
        fmt = heasig.fmt(sig_idx(1));
        ECG(:,sig_idx) = read_MIT_ecg( [recording_path heasig.fname(sig_idx(1),:)], ECG_start_idx, ECG_end_idx, nsig, fmt, heasig);
    end    
    ECG = int16(ECG);
    
end

function ECG = read_MIT_ecg(recording_name, ECG_start_idx, ECG_end_idx, nsig, fmt, heasig)
    
    if( fmt == 16)

        ECG_size = ECG_end_idx - (ECG_start_idx-1);
        
        fidECG = fopen(recording_name, 'r');
        try
            fseek(fidECG, ((ECG_start_idx-1)*nsig)*2, 'bof');
            ECG = fread(fidECG, [nsig ECG_size ], '*int16')';
            fclose(fidECG);
        catch ME
            fclose(fidECG);
            rethrow(ME);
        end

    elseif(fmt == 212)

        ECG = rdsign212(recording_name, nsig, ECG_start_idx, ECG_end_idx);

    elseif(fmt == 310)

        ECG = read_310_format(recording_name, ECG_start_idx, ECG_end_idx, heasig  );

    elseif(fmt == 311)

        warning('read_ECG:UntestedRegion', 'Untested!! danger ...')
        ECG = read_311_format(recording_name, ECG_start_idx, ECG_end_idx, heasig  );

    else
        error('read_ECG:UnknownDataFormat', 'Unknown data format.')
    end
