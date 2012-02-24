function [indexes max_mod] = modmax(x,first_samp,threshold,signo)
% Function which returns the indexes of vector x in which there are
% local modulus maxima or minima whose modulus is greater than 
% threshold.
% if signo is 0, it doesn't matter, if signo is +1 or -1, it only searchs
% for modulus maxima positive or negative

lx = size(x,1);
indexes=[];

if( nargin < 2 || isempty(first_samp) )
    first_samp = [2 lx];
else
    if( length(first_samp) < 2 )
        first_samp = [first_samp lx];
    end
end

if( nargin < 3 || isempty(threshold) )
    threshold = 0;
end

if( nargin < 4 || isempty(signo) )
    signo = 0;
end


if( lx > first_samp(1) )

    s = sign(x);
    x = abs(x);

    sample_curr_idx = first_samp(1):first_samp(2)-1;
    sample_prev_idx = (first_samp(1)-1):first_samp(2)-2;
    sample_next_idx = (first_samp(1)+1):first_samp(2);
    
    localmax =    ( x(sample_curr_idx,:)  >= x(sample_prev_idx,:) ) ...
                & ( x(sample_curr_idx,:)  >  x(sample_next_idx,:) ...
                &   x( sample_curr_idx,:) >= threshold) ...
                & ( s(sample_curr_idx,:)*signo >=0 );   % if 0,it doesnt matter

    iAux = false(size(x));
    iAux(sample_curr_idx,:) = localmax;
    indexes = find(iAux);
    max_mod = x(indexes) .* s(indexes);

end
