%FEATSETCC Feature set combining classifier
%
%		DSET = FEATSETCC(DOBJ,COMBC)
%		DSET = DOBJ*FEATSETCC([],COMBC)
%
% INPUT
%   DOBJ   Dataset, classification matrix, output of some base classifier
%   COMBC  Combiner, e.g. MAXC (default VOTEC)
%
% OUTPUT
%   DSET   Dataset, classification matrix for the sets in DOBJ
%
% DESCRIPTION
% This routine combines object classification results of feature sets 
% stored in DOBJ. It is assumed that the current labels of DOBJ define
% objects belonging to the same feature set. Objects of the same feature 
% set are combined by COMBC into a single classification result and
% returned by DSET. 
%
% DSET gets as many objects as there are feature sets defined for DOBJ. 
% Effectively the first object of every feature set in DOBJ is replaced by 
% the combined result and other objects of that feature set are deleted. 
% DSET has the same feature labels (most likely class names) as DOBJ and 
% stores as object identifiers the feature set names (label list) of DOBJ. 
% A possible multi-labeling definition of DOBJ is preserved
%
% SEE ALSO
% DATASETS, FEATSETC, MULTI-LABELING

% Copyright: R.P.W. Duin, r.p.w.duin@prtools.org
% Faculty EWI, Delft University of Technology
% P.O. Box 5031, 2600 GA Delft, The Netherlands

function [dset,id] = featsetcc(dobj,combc)

if nargin < 2 | isempty(combc), combc = votec; end

if nargin < 1 | isempty(dobj)
	% define the mapping
	dset = mapping(mfilename,'untrained',{combc});
	dset = setname(dset,'Feature set combiner');
else % execution
	
	% we should have a proper dataset
	isdataset(dobj);
	
	% the class names are the feature set indices
	fsetnames = classnames(dobj);
	
	% retrieve datasize, and number of sets c
	[m,k,c] = getsize(dobj);
	
	% get number of objects for every set
	s = classsizes(dobj);
	
	% dobj is a classification matrix, so its features point to classes
	featlab = getfeatlab(dobj);
	
	% reserve spave for the result
	dset = dataset(zeros(c,k));

	% space the object identifiers of the first object per set
	id = zeros(c,1);
	
	t = sprintf('Combining %i sets: ',c);
	prwaitbar(c,t);
	
	% run over all sets
	for j=1:c
		prwaitbar(c,j,[t int2str(j)]);
		
		% get the objects in the set
		y = seldat(dobj,j);
		
		% the identifier of the first object
		id(j) = getident(y(1,:));
		
		%create a dataset with all objects in the set concatenated horizontally
		y = +y';
		y = dataset(y(:)');
		
		% give the the proper class labels
		y = setfeatlab(y,repmat(featlab,s(j),1));
		
		% now we can use to classifier combiners
		dset(j,:) = y*combc;
		
	end
	prwaitbar(0);
	
	% find the first objects of every set
	J = findident(dobj,id); 
	
	% and replace them by the set combining result
	% so object labels become set labels
	dset = setdata(dobj(J,:),dset);
	
	% give columns the classnames
	dset = setfeatlab(dset,featlab);
	
	% use set names as set identifiers
	dset = setident(dset,fsetnames);
end