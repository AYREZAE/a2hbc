
for field_names = rowvec(fieldnames(UCP_struct))
    ctrl_hdl = UCP_struct.(field_names{1});
    if( strcmpi(get(ctrl_hdl, 'type'), 'uicontrol' )  )
        set(  ctrl_hdl, 'Enable', 'on');
    end
end
