function x = ADC2realunits(x, zero, gain)

[CantSamp CantSig CanScales] = size(x);

if( CanScales > 1)
    x = cellfun(@(a)( bsxfun( @rdivide , bsxfun(@minus, double(a), rowvec(zero)), rowvec(gain)) ), mat2cell(x, CantSamp, CantSig, ones(1,CanScales) ), 'UniformOutput', false);
    x = cell2mat(x);
else
    x = bsxfun( @rdivide , bsxfun(@minus, double(x), rowvec(zero)), rowvec(gain));
end

