%CLASSNAMES Get names of classes of dataset or classifier
%
%  NAMES = CLASSNAMES(A,C)
%  NAMES = CLASSNAMES(W,C)
%
% INPUT
%  A      Dataset
%  W      Trained classifier
%  C      Class number(s) in class label list, default: all
%
% OUTPUT
%  NAMES  Names of classes (strings or numbers)
%
% DESCRIPTION
% Returns the names of the classes used in the dataset A or the classes
% used by the classifier W. If for datasets no output is requested the
% names and the sizes of the classes are printed on the screen.
% If given, just the names of the classes corresponding to the indices in
% C are returned.
%
% SEE ALSO
% DATASETS, MAPPINGS, CLASSSIZES

% Copyright: R.P.W. Duin, r.p.w.duin@prtools.org
% Faculty EWI, Delft University of Technology
% P.O. Box 5031, 2600 GA Delft, The Netherlands

function names = classnames(a,n)

	if nargin < 2, n = []; end
	
	if isa(a,'dataset')
		lablist = getlablist(a);
		if nargout < 1
			s = classsizes(a);
			if iscell(lablist), lablist = char(lablist); end
			if isstr(lablist)
				for j=1:size(lablist,1)
					fprintf('\n %6i  %s',s(j),lablist(j,:));
				end
			else
				for j=1:length(lablist)
					fprintf('\n %3i %6i',lablist(j),s(j));
				end
			end
			fprintf('\n\n');
		else
			names = lablist;
		end
	elseif isa(a,'mapping')
		if isuntrained(a)
			error('No classes defined for untrained classifiers or mappings')
		else
			names = getlabels(a);
		end
	else
		error('Dataset or trained classifier expected')
	end

	names = names(n,:);
	
	return
