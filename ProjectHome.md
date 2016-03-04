
```





```
# IMPORTANT #

## Note that this project was moved to a bigger one, [ecg-kit](http://marianux.github.io/ecg-kit/), a Matlab toolbox for cardiovascular signal processing. ##
```





```
## What is it ? ##

The Argentino-Aragonés heartbeat classifier (a2hbc)  is a Matlab script developed for research purposes during my PhD studies `[1]`. As you can guess, it is just a heartbeat classifier. The main objective of this software is to ease the performance comparison against other (hope better) heartbeat classifiers. You can also use it for classifying unlabeled ECG recordings.

## Features ##

The main features are:

  * Validated performance. The performance was thoroughly evaluated in `[2]`.
  * Several formats accepted (MIT, ISHNE, AHA and HES)
  * Open source. Documented and easily customizable.
  * Multiprocessing ready. It is ready to run in both a desktop PC or a high performance cluster.
  * user interface. The algorithm have a simple graphical user interface (GUI) to ease the labeling of heartbeat clusters.

## Downloading ##

Go to the [Downloads tab](http://code.google.com/p/a2hbc/downloads/list) and look for any revision, or just click [here](http://a2hbc.googlecode.com/files/Ver%200.1%20beta.7z).

You can also download this tutorial in PDF format [here](http://a2hbc.googlecode.com/files/a2hbc_tutorial.pdf), or read it [online](http://es.scribd.com/doc/81951985/a2hbc-Tutorial).

## Forum ##

<table cellspacing='0'>
<blockquote><tr><td>
<img src='http://groups.google.com/intl/en/images/logos/groups_logo_sm.gif' />
</td></tr>
<tr><td>
<b>a2hbc users</b>
</td></tr>
<tr><td> <a href='https://groups.google.com/forum/?fromgroups&hl=en#!forum/a2hbc-users'>Check this group</a> </td></tr>
</table></blockquote>


## Usage ##

Several examples are included in the ''examples.m'' script. In this tutorial we will show some examples that any user can run to understand how to use A2HBC, with some ECG recordings included. It can be executed simply by its name:

```
>>a2hbc
```

In this case the ''control panel'' is displayed to gather some information from the user:

https://a2hbc.googlecode.com/svn/wiki/control_panel_d.PNG

You must enter the recording file name and its format, the other controls you can leave with its default values by the moment. You can select the ''208.dat'' recording, included in the ''example recordings ''folder, and set the ''MIT'' format. Then press ''Run!, ''the script will start working. You can follow the evolution in the progress bar, and after a while, it ends and display the classification results

```
Configuration 
------------- 
+ Recording: ... \example recordings\208.dat (MIT) 
+ Mode: auto (12 clusters, 1 iterations, 75% cluster-presence) 
 
  True            | Estimated Labels 
  Labels          | Normal Suprav Ventri Unknow| Totals 
 -----------------|----------------------------|------- 
  Normal          | 1567      6     13      0  | 1586 
  Supraventricular|    2      0      0      0  |    2 
  Ventricular     |  255      8   1102      0  | 1365 
  Unknown         |    2      0      0      0  |    2 
 -----------------|----------------------------|------- 
  Totals          | 1826     14   1115      0  | 2955 
 
Balanced Results for 
--------------------- 
| Normal    || Supravent || Ventricul ||           TOTALS            | 
|  Se   +P  ||  Se   +P  ||  Se   +P  ||   Acc   |   Se    |   +P    | 
|  99%  45% ||   0%   0% ||  81%  99% ||   60%   |   60%   |   48%   | 
 
Unbalanced Results for 
----------------------- 
| Normal    || Supravent || Ventricul ||           TOTALS            | 
|  Se   +P  ||  Se   +P  ||  Se   +P  ||   Acc   |   Se    |   +P    | 
|  99%  86% ||   0%   0% ||  81%  99% ||   90%   |   60%   |   62%   |
```


This is possible because this recording include the expert annotations, or ''ground truth'', for each heartbeat. The manual annotations in MIT format are typically included in ''.atr'' files (in this case ''208.atr''). Now you can check other operation modes, as the ''slightly-assisted''. Click on ''Run!'' and then, eventually, the algorithm may ask you for help.'' ''In case of needing help, a window like this will appear:

![https://a2hbc.googlecode.com/svn/wiki/2D__Mariano_misc_a2hbc_doc_expert_user_interface.png](https://a2hbc.googlecode.com/svn/wiki/2D__Mariano_misc_a2hbc_doc_expert_user_interface.png)

In this window the algorithm is asking you to label the centroid of the cluster, that is showed in the left panel. In the top of each panel some information is showed, as the amount of heartbeats in the current cluster. In the middle panel, you have some examples of heartbeats close to the centroid in a likelihood sense. The same is repeated in the right panel, but with examples far from the centroid. This manner you can have an idea of the dispersion of heartbeats within a cluster. Large differences across the panels indicates large cluster dispersion. If you decide to label the cluster, you can use one of the 4 buttons on your right. The unknown class is reserved for the cases where you can not make a confident decision. At the same time, in the command window, a suggestion appears:

```
Configuration 
------------- 
+ Recording: .\example recordings\208.dat (MIT) 
+ Mode: assisted (3 clusters, 1 iterations, 75% cluster-presence) 
Suggestion: Normal
```

This means that the centroid heartbeat in the ''.atr'' file is labeled as ''Normal''. You will see this suggestion for each cluster analyzed, if there are annotations previously available. You are informed about the percentage of heartbeats already labeled with a progress bar, in the bottom of the control panel window.

In case you believe that a cluster includes several classes of heartbeats, you can decide to ''skip'' the classification, and try to re-cluster those heartbeats in the next iteration. You are free to perform as many iterations as you decide, by skipping clusters. The refresh button resamples heartbeats close and far from the centroid, and then redraw the middle and right panels. This feature is useful for large clusters.

There are two possible ways of using A2HBC, in a single desktop PC or in a high performance cluster of computers.

### The power of the command-line ###

You can control all the features described up to the moment (and more) from the command-line of Matlab. This is particularly useful for integrating ''a2hbc'' in your scripts. You can find several examples in the script ''examples.m'', this is probably the best way of getting familiar with it. Here I reproduce some worked examples included in this script. First let's start executing

```
a2hbc( ... 
    ’recording_name’, [ ’.’ filesep ’example recordings’ filesep ’208.dat’], ... 
    ’recording_format’, ’MIT’, ... 
    ’op_mode’, ’auto’);
```

As you can see, the parameter interface of ''a2hbc'' is by ''name-value'' parameters. In the previous example, the name of the parameters are self-explanatory, the only comment is for the third, which is the operating mode. In Table  you can check the complete list of parameters. As a result, you will get similar results to the obtained in the first example using the GUI.

```
Configuration 
------------- 
+ Recording: .\example recordings\208.dat (MIT) 
+ Mode: auto (12 clusters, 1 iterations, 75% cluster-presence) 
 
  True            | Estimated Labels 
  Labels          | Normal Suprav Ventri Unknow| Totals 
 -----------------|----------------------------|------- 
  Normal          | 1575      3      8      0  | 1586 
  Supraventricular|    2      0      0      0  |    2 
  Ventricular     |  250      7   1108      0  | 1365 
  Unknown         |    1      0      1      0  |    2 
 -----------------|----------------------------|------- 
  Totals          | 1828     10   1117      0  | 2955 
 
Balanced Results for 
--------------------- 
| Normal    || Supravent || Ventricul ||           TOTALS            | 
|  Se   +P  ||  Se   +P  ||  Se   +P  ||   Acc   |   Se    |   +P    | 
|  99%  46% ||   0%   0% ||  81%  99% ||   60%   |   60%   |   48%   | 
 
Unbalanced Results for 
----------------------- 
| Normal    || Supravent || Ventricul ||           TOTALS            | 
|  Se   +P  ||  Se   +P  ||  Se   +P  ||   Acc   |   Se    |   +P    | 
|  99%  86% ||   0%   0% ||  81%  99% ||   91%   |   60%   |   62%   |
```

In the case that you would like to integrate a2hbc to your software, or you have a proprietary ECG format not allowed by a2hbc, the best choice is that you pass the ECG samples directly. For doing this, you will have follow the requirements in Table  indicated with a ^{2}, and



  * ECG is the ECG signal matrix of nsamp × nsig, in ADC samples.
  * ECG\_header is a struct with the ECG properties, with fields:
    * freq is the sampling rate of the ECG
    * nsamp is the number of samples
    * nsig is the amount of leads.
    * gain is a vector of nsig × 1 with the gain of each lead ( ADCsamples μ V ).
    * adczero is a vector of nsig × 1 with the offset of each lead in ADC samples.
  * QRS\_annotations is a struct with the location of the QRS complexes, with fields:
    * time is a vector of QRS\_amount × 1, with the sample value where the QRS complexes are.
    * ann\_type `[optional]` is a char vector of QRS\_amount × 1, with each heartbeat label. This field is for evaluating the performance of a classifier, as a result a2hbc generates the confusion matrix seen in the examples above.

The parameters 'cant\_pids' and 'this\_pid' are explained in the next section, since were designed for partitioning and multiprocessing of recordings. The parameter ''SimulateExpert'' was designed to simulate the expert input by using the expert annotations provided in the annotations files, or via the ''QRS\_annotations ''parameter. ''ClusterPresence'' is a threshold for evaluating the qualified majority in operating modes ''auto'' or ''slightly-assisted''. The lower this threshold the more confident the algorithm in labeling all heartbeats in a cluster as the centroid. ''Repetitions'' was designed to evaluate multiple times the algorithm performance in a particular recording. As a result, the computed confusion matrix is a 3-D cube with the amount of repetitions as the third coordinate. With this kind of confusion matrix it is possible to estimate the dispersion of the results presented in `[1,2]`. Finally, the ''ClusteringRepetitions'' parameter requires a special explanation, since it was not described in the bibliography. In few words, it is a trick for increasing the clustering resolution for complex or long-term recordings. The higher this parameter, the higher the amount of cluster found and, at the end, the assistance required by the algorithm.

From the user point of view, you should be satisfied with this clue, however if you are interested in the trick, I will explain it with a toy example. Consider the following clustering problem, where we are interested in finding 3 clusters.

![https://a2hbc.googlecode.com/svn/wiki/3D__Mariano_misc_a2hbc_doc_clust_rep_ex1.png](https://a2hbc.googlecode.com/svn/wiki/3D__Mariano_misc_a2hbc_doc_clust_rep_ex1.png)

Now if we repeat the same process two times, our clustering algorithm does not guarantee to find the same partition. However our intuition tells us that in case where the classes are well separated, the partition is likely to remain very similar through the repetitions. In the opposite case, the partition can change. Then after N repetitions, the ''QRS\_amount ''heartbeats were assigned N cluster labels.

![https://a2hbc.googlecode.com/svn/wiki/4D__Mariano_misc_a2hbc_doc_clust_rep_ex2.png](https://a2hbc.googlecode.com/svn/wiki/4D__Mariano_misc_a2hbc_doc_clust_rep_ex2.png)

So the number of clusters increase according to ''N''. In order to keep this number in the order of tens, it was used a merging criterion for ''similar cluster''s. The similarity is measure in terms of labeling differences across the repetitions. For example:

![https://a2hbc.googlecode.com/svn/wiki/5D__Mariano_misc_a2hbc_doc_clust_rep_ex3.png](https://a2hbc.googlecode.com/svn/wiki/5D__Mariano_misc_a2hbc_doc_clust_rep_ex3.png)

Then we can group together some clusters based on this labeling distance. The ''a2hbc'' group together clusters within a distance of 0.2·N.

Table 1: List of parameters of a2hbc.

| Name | Value |  | Description |
|:-----|:------|:-|:------------|
|      | default | validation |             |
| 'recording\_name' | –     | char | The file name of the ECG recording 1 |
| 'recording\_format' | –     | {MIT, 'ISHNE', 'AHA', 'HES', 'MAT'} | The format of the ECG recording 1 |
| 'ECG' | –     | numeric | The ECG samples 2 |
| 'ECG\_header' | –     | struct | Struct with ECG features 2,3 |
| 'QRS\_annotations' | –     | numeric && all(x >= 1) | Sample occurrence of QRS complexes 2 |
| 'op\_mode' | 'auto' | {'auto', 'slightly-assisted', 'assisted'} OR 1 = x = 3 |
| 'cant\_pids' | 1     | x >= 1 | How many processes in total to compute this recording 3 |
| 'this\_pid' | 1     | x >= 1 && x <= 'cant\_pids' | Which of the processes is this. 3 |
| 'CacheData' | true  | logical | Save intermediate results to speed-up re-processing ? |
| 'InteractiveMode' | false | logical | Show the control panel after processing the recording. |
| 'SimulateExpert' | false | logical | Use expert annotations to simulate expert interaction 3 |
| 'tmp\_path' | –     | char | Path to store intermediate results. |
| 'NumOfClusters' | 12    | x > 1 | Number of cluster to search. |
| 'ClusteringRepetitions' | 1     | 1 <= x <= 10 | Repetitions of the clustering process. 3 |
| 'ClusterPresence' | 75    | 0 <= x <= 100 | Threshold for the qualified majority. 3 |
| 'Repetitions' | 1     | x >= 1 | Repetitions to evaluate this recordings. 3 |

1 and 2 indicates groups of parameters that can not be mixed. You can specify file name and format, or pass the ECG samples, QRS annotations, etc.

3 See a complete explanation in the text, or in the references `[1, 2]`.



### The power of a high performance computing cluster ###

Maybe one of the most useful features of ''a2hbc'' is that was developed for being used in a high performance computing cluster. The parameters ''cant\_pids'' and ''this\_pid'' controls the partitioning of the work for each recording.

```
% Computer 1 
 
lab1 = a2hbc( ... 
    ’recording_name’, [ ’.’ filesep ’example recordings’ filesep ’208.dat’], ... 
    ’recording_format’, ’MIT’, ... 
    ’this_pid’, 1, ... 
    ’cant_pid’, 2, ... 
    ’op_mode’, ’auto’); 
 
% Computer 2 
 
lab2 = a2hbc( ... 
    ’recording_name’, [ ’.’ filesep ’example recordings’ filesep ’208.dat’], ... 
    ’recording_format’, ’MIT’, ... 
    ’this_pid’, 2, ... 
    ’cant_pid’, 2, ... 
    ’op_mode’, ’auto’); 
 
 
% Somewhere: results collection and processing 
lab = [lab1; lab2]; 
...
```

It is recommended to adapt this features to the batch manager available in your computing facilities. In the case of our University, the batch manager used is Condor `[3]`. You can ask me for the condor implementation for multiprocessing, but the details of this are outside of the scope of this tutorial.

## Acknowledgments ##

This software was supported by the University of Zaragoza, Spain and the National Technical University of Buenos Aires, Argentina.
Thanks to Biosigna GmbH for the database and the HES format documentation.

## Bibliography ##

  1. Llamedo, M., Martínez, J. P. (2011). [Heartbeat Classification Using Feature Selection Driven by Database Generalization Criteria](http://www.ncbi.nlm.nih.gov/pubmed/20729162) [(Online preprint)](http://diec.unizar.es/~laguna/personal/publicaciones/LlamedoIEEE2011.pdf). IEEE TRANSACTIONS ON BIOMEDICAL ENGINEERING, 58(3), 616-625. doi:10.1109/TBME.2010.2068048
  1. Llamedo, M., Khawaja, A., Martínez, J. P., & Martinez, J. P. (2012). [Cross-Database Evaluation of a Multilead Heartbeat Classifier](http://www.ncbi.nlm.nih.gov/pubmed/22531814) [(Online preprint)](http://diec.unizar.es/~laguna/personal/publicaciones/LlamedoIEEE-TITB2012.pdf). IEEE transactions on information technology in biomedicine : a publication of the IEEE Engineering in Medicine and Biology Society, 16(4), 658-64. doi:10.1109/TITB.2012.2193408
  1. Llamedo, M., Martinez Cortes, J.P (2012). [An Automatic Patient-Adapted ECG Heartbeat Classifier allowing Expert Assistance](http://www.ncbi.nlm.nih.gov/pubmed/22692868) [(Online preprint)](http://diec.unizar.es/~laguna/personal/publicaciones/LlamedoIEEE-TBME2012.pdf). IEEE transactions on bio-medical engineering, (c), 1-9. doi:10.1109/TBME.2012.2202662
  1. Llamedo, M., Martinez Cortes, J.P. [PhD thesis](http://i3a.unizar.es/postgrado/descarga_tesis_pdf.php?ver=48), [Master thesis](http://i3a.unizar.es/postgrado/descarga_memoria_pdf.php?ver=116)
  1. “Condor high throughput computing system,” 2010. Available: http://www.cs.wisc.edu/condor/