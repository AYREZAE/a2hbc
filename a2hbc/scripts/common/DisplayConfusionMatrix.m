function DisplayConfusionMatrix( C, lablist )

cant_iter = size(C,3);

labcv = lablist;
n1 = size(lablist,1);
n2 = n1;

if (size(lablist,2) > 6)
    lablist = lablist(:,1:6); 
    %labcv = labcv(:,1:6); 
end
if (size(lablist,2) < 5)
    lablist = [lablist repmat(' ',n2,ceil((5-size(lablist,2))/2))]; 
    labcv = [labcv repmat(' ',n1,ceil((5-size(labcv,2))/2))]; 
end

nspace = max(size(labcv,2)-7,0);
cspace = repmat(' ',1,nspace);
%fprintf(1,['\n' cspace '        | Estimated Labels']);
fprintf(1,['\n  True   ' cspace '| Estimated Labels']);
fprintf(1,['\n  Labels ' cspace '|']);
for j = 1:n2, fprintf(1,'%7s',lablist(j,:)); end
fprintf(1,'|');
fprintf(1,' Totals');
fprintf(1,'\n ');
fprintf(1,repmat('-',1,8+nspace));
fprintf(1,'|%s',repmat('-',1,7*n2));
fprintf(1,'|-------');
fprintf(1,'\n ');

if( cant_iter > 1 )
    C_mean = round(mean(C,3));
    C_std = round(std(C,0,3));
    C_sum2 = sum(C,2);
    C_sum1 = sum(C,1);
end

for j = 1:n1
    fprintf(1,' %-7s|',labcv(j,:));
    if( cant_iter > 1 )
        c_aux = colvec([ colvec(C_mean(j,:)) colvec(C_std(j,:)) ]');
        fprintf(1,repmat(' %i(%i) ', 1, n1), c_aux);
        fprintf(1,'| %i(%i)\n', round(mean(C_sum2(j,:,:),3)), round(std(C_sum2(j,:,:),0,3)) );
    else
        fprintf(1,' %5i ',C(j,:)');
        fprintf(1,'| %5i\n',sum(C(j,:)));
    end
end

fprintf(1,repmat('-',1,8+nspace));
fprintf(1,'|%s',repmat('-',1,7*n2));
fprintf(1,'|-------');
fprintf(1,['\n  Totals ' cspace '|']);

if( cant_iter > 1 )
    c_aux = colvec([ colvec(round(mean(C_sum1,3))) colvec(round(std(C_sum1,0,3))) ]');
    fprintf(1,repmat(' %i(%i) ', 1, n1), c_aux);
    fprintf(1,'| %i(%i)\n\n', round(mean(sum(C_sum1,2),3)), round(std(sum(C_sum1,2),0,3)) );
else
    fprintf(1,' %5i ',sum(C));
    fprintf(1,'| %5i\n\n',sum(C(:)));
end
