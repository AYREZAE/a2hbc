function strRetVal = Seconds2HMS(data)

sign_data = sign(data);
data = abs(data);

iHours = floor(data * 1 / 60 / 60);
iMins = floor(data * 1 / 60 - iHours * 60 );
iSeconds = data - iHours * 60  * 60 - iMins * 60;

ldata = length(data);
strRetVal = cell(ldata,1);

for ii = 1:ldata
    
    if( sign_data(ii) < 0 )
        strAux = '-'; 
    else
        strAux = [];
    end
    
    if( iHours(ii) > 0 )
        strAux = [   num2str(iHours(ii)) ' hs ' ]; 
    end

    if( iMins(ii) > 0 )
        strAux = [  strAux num2str(iMins(ii)) ''' ' ]; 
    end

    strAux = [  strAux sprintf( '%2.1f"', iSeconds(ii)) ]; 

    strRetVal{ii} = strAux;
    
end

strRetVal = char(strRetVal);
