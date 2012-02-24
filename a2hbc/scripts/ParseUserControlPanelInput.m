
if( ishandle(UCP_struct.fig_hdl) )
    %classifier arguments
    recording_name = get(UCP_struct.recording_name, 'String');
    recording_format = cKnownFormats{get(UCP_struct.recording_fmt, 'Value')};
    tmp_path = get(UCP_struct.tmp_path, 'String');
    op_mode = cKnownModesOfOperation{get(UCP_struct.op_mode, 'Value')};

    %clustering options
    CantClusters = get(UCP_struct.CantClusters, 'Value');
    iter_times = get(UCP_struct.iter_times, 'Value');
    cluster_presence = get(UCP_struct.cluster_presence, 'Value');

    %User interface options
    CantSamplesClose = str2double(get(UCP_struct.CantSamplesClose, 'String'));
    CantSamplesFar = str2double(get(UCP_struct.CantSamplesFar, 'String'));
end
