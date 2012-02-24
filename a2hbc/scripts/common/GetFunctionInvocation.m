function strAux = GetFunctionInvocation( funcName, args)

strAux = sprintf( [ 'Invocation: ' funcName '(']);
for ii = 1:length(args)
    if( ischar(args{ii}) )
        strAux = [strAux sprintf('''%s''', args{ii})];
    elseif(isnumeric(args{ii}))
        strAux = [strAux sprintf( num2str(args{ii}))];
    elseif(islogical(args{ii}))
        if( args{ii} )
            strAux = [strAux sprintf('true')];
        else
            strAux = [strAux sprintf('false')];
        end
    end
    strAux = [strAux sprintf(', ')];
end
strAux = [strAux(1:end-3) ')' ];
