%FEATSETC Set classifier
%
%		[WSET,WOBJ] = FEATSETC(A,OBJCLASSF,FSETINDEX,FSETCOMBC,FSETCLASSF,FSETLAB)
%		D = B*WSET
%
% INPUT
%   A          Dataset with object labels and feature set indices 
%              used for training
%   B          Dataset with index list of sets, stored as label list 
%   OBJCLASSF  Trained or untrained object classifier, default QDC
%   FSETINDEX  String name or number for index list of feature sets, 
%              stored as label list in A, default 2.
%   FSETCOMBC  Combiner for objects in a feature set, default VOTEC
%   FSETCLASSF Untrained classifier for feature sets, default FISHERC
%   FSETLAB    String name or number for label list of feature sets, stored
%              as label list in A. Objects with the same feature set index
%              should have the same feature set label. 
%              Default is the current labeling of A
%
% OUTPUT
%   WSET       Trained feature set classifier
%   WOBJ       Trained object classifier
%   D          Classification matrix of feature sets in B
%
% DESCRIPTION
% This routine offers a classifier for feature sets (e.g. images) of objects
% (e.g. pixels) stored in a single dataset. The objects in the training 
% set A should have two labels: class labels and feature set indices, stored by the
% ADDLABELS command in the multi-labeling system (see MULTI_LABELING)
% offered by PRTools. The object labels should be the current labeling of A
% defined by CHANGELABLIST.  FSETINDEX should be the label list name or
% number referring to the label list used for storing the feature set indices that 
% define to which set an object belongs. The same label list name or number
% should be used for the objects in B.
%
% All objects in A are used to train the object classifier OBJCLASSF if it 
% is untrained. Classification results of the objects in the same set are
% combined by FSETCOMBC, which can be any of the fixed combiners MEANC,
% PRODC, PERC, MINC, MAXC, etcetera. This results for every set in a single
% confidence vector for the classes. 
%
% If an untrained set classifier FSETCLASSF is supplied, the  set confidence
% vectors are used to train a set classifier.
%
% New sets, organised in a dataset like B, with the proper set indices per
% object stored in a label list with the same name or number as just in A,
% can be classified by the set classifier WSET. 
%
% If no set classifier FSETCLASSF was defined during training, just the
% results of the object classifier WOBJ are returned combined by FSETCOMBC
% over the objects in the same set in B. In this case the final result is
% identical to B*(A*WOBJ)*SETCC([],FSETCOMBC), provided that A has class
% labels and B is labeled by its set indices.
%
% SEE ALSO
% DATASETS, MAPPINGS, MULTI_LABELING, FEATSETCC, LOSO,
% DATASET/ADDLABELS, DATASET/CHANGELABLIST

% Copyright: R.P.W. Duin, r.p.w.duin@prtools.org
% Faculty EWI, Delft University of Technology
% P.O. Box 5031, 2600 GA Delft, The Netherlands

function [out1,out2] = featsetc(a,objclassf,fsetindex,fsetcombc,fsetclassf,fsetlab)

if nargin < 6 | isempty(fsetlab),    fsetlab = []; end
if nargin < 5 | isempty(fsetclassf), fsetclassf = []; end
if nargin < 4 | isempty(fsetcombc),  fsetcombc  = votec; end
if nargin < 3 | isempty(fsetindex),  fsetindex  = 2; end
if nargin < 2 | isempty(objclassf),  objclassf  = qdc; end

if nargin < 1 | isempty(a)
	% define the mapping
	wset = mapping(mfilename,'untrained',{objclassf,fsetindex,setcombc,fsetclassf,fsetlab});
	out1 = setname(wset,'Set classifier');

elseif isuntrained(objclassf) | nargin > 2 | ~strcmp(getmapping_file(objclassf),mfilename)
	% train the mapping (classifier)

	% we need datasets with at least 1 object per class and 2 classes
	isvaldset(a,1,2);
	
	% if the object classifier is untrained, train it, else use it
	if isuntrained(objclassf)
		wobj = a*objclassf;
	else
		wobj = objclassf;
	end
	
	if ismapping(fsetclassf) & isuntrained(fsetclassf)
		
		% if the feature set labels are not given, 
		% use the objcts labels for the sets too
		if isempty(setlab), setlab = curlablist(a); end
	
		% classifiy the dataset and change labeling to set index
		x = changelablist(a*wobj,setindex);
		
		% avoid empty sets
		x = setlablist(x);
	
		% combine object results to set results
		d = featsetcc(x,fsetcombc);
	
		% change to set labels
		d = changelablist(d,fsetlab);
	
		% train set classifier
		fsetclassf = d*fsetclassf;
		
		% get outputlabels
		labels_out = getlabels(fsetclassf);
		
	else
		labels_out = getlabels(wobj);
	end
	
	% store all what is needed for execution in the mapping
	out1 = mapping(mfilename,'trained',{wobj,fsetcombc,fsetclassf,fsetindex,fsetlab}, ...
		labels_out, size(a,2),size(labels_out,1));
	
	% prevent batch execution
	out1 = setbatch(out1,0);
	
	% return the object classifier as well
	out2 = wobj;
	
else % here we are for execution
		
	% the mapping is stored in objclassf
	w = getdata(objclassf);
	
	% save current lablist
	curlist = curlablist(a);
	
	% use the set index for the test set if supplied
	if ~isempty(w{4}), testset = changelablist(a,w{4}); end
	
	% classify test set by the object classifier
	d = testset*w{1};
		
	% avoid empty sets
	d = setlablist(d);
	
	% combine objects in the same set
	d = featsetcc(d,w{2}); 
	
	% reset lablist for classification matrix
	d = changelablist(d,curlist);
	
	% apply the set classifier, if defined
	if ~isempty(w{3}), d = d*w{3}; end
	
	% that is it, define class labels as feature labels
	out1 = setfeatlab(d,getlabels(objclassf));
	
end
	
	
	
	
	
	