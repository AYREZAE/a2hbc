
% op_mode parsing
if( isnumeric(op_mode) )
    op_mode = cKnownModesOfOperation{op_mode};
end

%ECG parsing
if( ~isempty(ECG_total) )
    % ECG already read

    if( isempty(ECG_header))
       error( 'a2hbc:ArgCheck:InvalidHeader', 'Please provide the ECG header.\n\n' );
    else
        if( ~isfield(ECG_header, cHeaderFieldNamesRequired ) )
            strAux = [ repmat(' + ', length(cHeaderFieldNamesRequired), 1) char(cHeaderFieldNamesRequired) repmat('\n', length(cHeaderFieldNamesRequired), 1 ) ];
            error( 'a2hbc:ArgCheck:InvalidHeader', ['Please provide the following fields in the header struct:\n ' rowvec(strAux') ] );
        end
    end
    
    heasig = ECG_header;
    
    if( isempty(ECG_annotations))
       error( 'a2hbc:ArgCheck:InvalidHeader', 'Please provide the ECG annotations.\n\n' );
    else
        if( ~isfield(ECG_annotations, cAnnotationsFieldNamesRequired ) )
            strAux = [ repmat(' + ', length(cAnnotationsFieldNamesRequired), 1) char(cAnnotationsFieldNamesRequired) repmat('\n', length(cAnnotationsFieldNamesRequired), 1 ) ];
            error( 'a2hbc:ArgCheck:InvalidAnnotations', ['Please provide the following fields in the annotations struct:\n ' rowvec(strAux') ] );
        end
    end
    
    ann = ECG_annotations;
    
elseif( ~isempty(recording_name) )
    % ECG to be read
    
    [~, rec_filename] = fileparts(recording_name);

    if( isempty(recording_format) )
       strAux = [ repmat(' + ', length(cKnownFormats), 1) char(cKnownFormats) repmat('\n', length(cKnownFormats), 1 ) ];
       error( 'a2hbc:ArgCheck:InvalidFormat', ['Unknown format. Choose one of the following:\n' rowvec(strAux') ] );
    end
    
    if( ~exist_distributed_file(recording_name, Retries2findfiles) )
       error( 'a2hbc:ArgCheck:RecNotFound', 'Can not find recording : %s', recording_name );
    end
    
    if( strcmp(recording_format, 'MIT') )
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
            error( 'a2hbc:ArgCheck:AnnNotFound', 'Can�t find QRS complex detections for file : %s', recording_name  );
        end
        
        ann = readannot(annFileName);
        heasig = readheader([recording_name(1:end-3) 'hea']);
        
    elseif( strcmp(recording_format, 'ISHNE') )
        annFileName = [recording_name(1:end-3) 'ann'];
        if( exist(annFileName, 'file') )
            ann = read_ishne_ann(annFileName);
        else
            error( 'a2hbc:ArgCheck:AnnNotFound', 'Can�t find QRS complex detections for file : %s', recording_name  );
        end        
        heasig = read_ishne_header(recording_name);
    elseif( strcmp(recording_format, 'HES') )
        ann = read_HES_ann([recording_name(1:end-3) 'lst']);
        heasig = read_HES_header(recording_name);
        ann.time = round(ann.time * heasig.freq);
    elseif( strcmp(recording_format, 'AHA') )
        ann = read_AHA_ann(recording_name);
        heasig = read_AHA_header(recording_name);
    elseif( strcmp(recording_format, 'MAT') )
        aux_load = load(recording_name);
        
        if( ~isfield( aux_load, 'ECG') || ~isfield( aux_load, 'ann') || ~isfield( aux_load, 'heasig') )
            error( 'a2hbc:ArgCheck:InvalidECGarg', 'MAT file does not include the required variables, help(''a2hbc'') maybe could help you.\n' );
        end
        
        ann = aux_load.ann;
        ECG = aux_load.ECG;
        heasig = aux_load.heasig;
        
        clear aux_load
        
    end

else
%     strAux = help('a2hbc'); %#ok<MCHLP>
    error( 'a2hbc:ArgCheck:InvalidECGarg', 'Please provide an ECG recording as described in the documentation, help(''a2hbc'') maybe could help you.\n' );
end

%In this case we need the true labels labeled from an expert.
if( isfield( ann, 'anntyp'))
    % Annotations filtering and conversion
    ann = AnnotationFilterConvert(ann, recording_format);

    %debug and performance asssesment only 
    true_labels = ann.anntyp;
else
    if( bSimulateExpert )
        error( 'a2hbc:ArgCheck:TrueLabelsNotFound', 'Can�t find true labels for file : %s', recording_name  );
    end
end

QRS_locations = ann.time;

if( isempty(tmp_path) )
    tmp_path = [fileparts(mfilename('fullpath')) filesep 'tmp' filesep ];
%     tmp_path = [fileparts(recording_name) filesep ];
end

%check path integrity.
if(~exist(tmp_path, 'dir'))
    %try to create it
    if( ~mkdir(tmp_path) )
        error('a2hbc:ArgCheck:InvalidPath', 'Invalid tmp_path. Please provide a valid path.\n' );
    end
end

recording_name_old = recording_name;

bArgCheckPassed = true;
           
