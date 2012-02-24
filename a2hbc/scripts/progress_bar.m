function progress_struct = progress_bar(arg1, arg2, arg3)

% Description:
% 
% Arguments:
%   + ECG: signal to be cleaned.
%   + sampling_rate: sampling rate of the ECG.
% 
% Output:
%   + ECG: clean ECG.
% 
% 
% Limits and Known bugs:
% 
% Author: Mariano Llamedo Soria (llamedom at {electron.frba.utn.edu.ar; unizar.es}
% Birthdate  : 23/8/2011
% Last update: 23/8/2011

%Only for Matlab in interactive mode.
if(~usejava('desktop'))
    progress_struct = [];
    return
end

%constant for the waitbar
bar_position = [0.05    0.3    0.9    0.25];

if( isnumeric(arg1) )
    %% loop mode
    
    if( nargin > 1 && isstruct(arg2) )
        progress_struct = arg2;
    else
        error('progress_bar:StructNotProvided', 'Need the progress_struct struct as 2nd argument.')
    end
    
    if(arg1 == 0)
        %start of loop. Reset timers
        progress_struct.tic = tic;
    elseif(arg1 == 100)
        %end of loop. Calculate averages.
        progress_struct.LoopTimes = [progress_struct.LoopTimes; toc(progress_struct.tic)];
        progress_struct.LoopMeanTime = mean(progress_struct.LoopTimes);
        progress_struct.LoopsDone = progress_struct.LoopsDone + 1;
    else
        warning('progress_bar:UnknownCommand', 'Unknown command. Use ''on'' or ''off''.')
    end
    
    return
    
elseif( ischar(arg1) )
    %% on - off 
    strCommand = arg1;
    
    if( nargin > 1 && ischar(arg2) )
        strMessage = arg2;
    else
        strMessage = '';
    end
    
    if( strcmpi('on', strCommand) )
        %% waitbar initialization
        
        progress_struct.handle = waitbar(0, '', 'name', strMessage );
        set(progress_struct.handle, 'Tag', 'progress_bar');
        wbar_hdl = findobj(progress_struct.handle,'Type','Axes');
        set(wbar_hdl, 'units','normalized' );
        set(wbar_hdl, 'position',  bar_position);
        
        progress_struct.LoopTimes = [];
        progress_struct.LoopMeanTime = [];
        progress_struct.counter = 0;
        progress_struct.strTitle = strMessage;
        progress_struct.LoopsDone = 0;
        
        % Loops to do.
        if( nargin > 2 && isnumeric(arg3) )
            progress_struct.Loop2do = arg3;
        else
            progress_struct.Loop2do = [];
        end
        
        
    elseif( strcmpi('off', strCommand) )
        %% waitbar close
        
        if( ishandle(arg2.handle) )
            close(arg2.handle);
        end
    else
        warning('progress_bar:UnknownCommand', 'Unknown command. Use ''on'' or ''off''.')
    end
    
    return

elseif( isstruct(arg1) )
    %% Inside a loop or just indicate evolution
    
    progress_struct = arg1;

    if( isempty(progress_struct.LoopMeanTime) )
        %first loop, learning times. Just to show time evolution.
        progress_struct.counter = progress_struct.counter + 0.1;
        currTime = 0;
    else
        %estimate progress
        currTime = toc(progress_struct.tic);
        progress_struct.counter = currTime/progress_struct.LoopMeanTime;
    end 

    % take care always a waitbar to draw.
    if( ~ishandle(progress_struct.handle) )
        progress_struct.handle = waitbar(0);
        set(progress_struct.handle, 'Tag', 'progress_bar');
        wbar_hdl = findobj(progress_struct.handle,'Type','Axes');
        set(wbar_hdl, 'units','normalized' );
        set(wbar_hdl, 'position', bar_position );
    end
    
    if( nargin > 1 && ischar(arg2) )
        waitbar( progress_struct.counter - fix(progress_struct.counter), progress_struct.handle, arg2 );
    else
        waitbar( progress_struct.counter - fix(progress_struct.counter), progress_struct.handle );
    end
    
    if( ~isempty(progress_struct.Loop2do) && ~isempty(progress_struct.LoopMeanTime) )
        set(progress_struct.handle, 'Name', [ progress_struct.strTitle '. Finishing in ' Seconds2HMS((progress_struct.Loop2do-progress_struct.LoopsDone) * progress_struct.LoopMeanTime - currTime) ]);
    end
    
else
    strAux = help(mfilename); %#ok<MCHLP>
    error('progress_bar:UnkArguments', ['Unknown arguments. See documentation:\n\n' strAux ]);
end
