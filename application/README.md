# Pipeline of biography prediction

## Introduction

This is the workflow of the pipeline to predict forensic georgic coordinates.

There are 2 main steps:

  1. The admixture proportions with respect to reference populations (i.e. 9 putative ancestral populations: North East Asian, South West Asian, South East Asian, Mediterranean, Northern European, Southern African, Subsaharan African, Oceanian, and Native American) was calculated for the individuals in the training set by implementing ADMIXTURE with supervised approach on an ancestry informative markers (AIMs) set.

There are 2 curated SNPs set in different sizes (saved in *SNPs_set*):

  * Benchmark SNPs set: 6,805 SNPs
  * Split300 SNPs set: 300 SNPs

That can be used for different application purposes. Benchmark SNPs set has very similar prediction accuracy to >100,000 SNPs while its size is much larger than split300. 
The accuracy of split300 is relatively smaller by comparing to Benchmark, but is small in size, which can be wider applied in forensic investigation.

  2. Admixture portions of individuals in the training set were trained with geographic coordinates (latitude and longitude) in Random Forest (RF) regression to predict the geographic coordinates of individuals in the test set. The predicted geographic coordinates were then refined if they could not fall within any country.

If the test set (such as the example test set in *example_input*) contains origin geographic coordinates, the distance between the original and predicted geographic coordinates can be calculated to check the performance of the pipeline.


## Usage 

Follow the workflow below with the example in *example_input* to go over how to use the pipeline and what the input for each function should be. 
All functions are separately saved in *function* directory with the function name as the R script name. The prediction output will be saved in *output* directory.
Data will be used is in *application_data*

## Dependencies

Required packages can be found in ***../packages.r*** 

## Application workflow

#### Get the overlapping SNPs between the given test set and our training set
```console 
plink --bfile example_input/output_645 --extract application_data/test_overlap.bim --make-bed --out output/baseline_overlap

# count the number of SNPs for the given trst set after extracting overlapped SNPs
wc -l output/baseline_overlap.bim
wc -l application_data/test_overlap.bim
```
Note that if the size of overlapped SNPs in the given test set is much smaller than the number of SNPs in our training set (test_overlap), the prediction accuracy may be low. In forensic application, since the kit can make based on our SNPs set, the missing SNPs will not happen.

#### Merge the reference populations to the given test set
```console
plink --bfile output/baseline_overlap --bmerge application_data/genepool_overlap_qc.bed application_data/genepool_overlap_qc.bim application_data/genepool_overlap_qc.fam --make-bed --out output/output_genepool --allow-no-sex
```

#### Select a SNPs set and extract SNPS from pout training set and the given test set
We use split300 SNPs set in the example code
```console
plink --bfile application_data/test_overlap --extract SNPs_set/split300.snp  --make-bed --out output/test_overlap_split300
plink --bfile output/output_genepool --extract SNPs_set/split300.snp  --make-bed --out output/baseline_overlap_split300

wc -l baseline_overlap_split300.bim
```
Again, if the number of SNPs after extracting SNPs from split300 is not 300. The prediction accuracy cannot correctly show the power of our pipeline.

#### Prepare population file for both the given test set and out training set
```console
### for the training set
cut -f1-2 -d ' ' application_data/test_overlap_split300.fam > application_data/test_overlap_split300.pop.txt
printf '%.0s\n' {1..3550} > application_data/test_overlap_split300.pop
cat application_data/test_overlap_split300.pop.txt | grep -E 'NorthEastAsian|Mediterranean|SouthAfrican|SouthWestAsian|NativeAmerican|Oceanian|SouthEastAsian|NorthernEuropean|SubsaharanAfrican' | cut -f1 -d' ' >> application_data/test_overlap_split300.pop

# Run ADMIXTURE in supervised approach
~/admixture32 application_data/test_overlap_split300.bed -F 9 -j48
cat application_data/test_overlap_split300.fam | cut -d ' ' -f1-2 > output/test_overlap_out_ind_id
sed -i 's/ /\t/g' output/test_overlap_out_ind_id
sed -i 's/ /\t/g' application_data/test_overlap_split300.9.Q
paste output/test_overlap_out_ind_id application_data/test_overlap_split300.9.Q > output/out_Q_test_overlap_split300
sed -i '1 i\Populations\tGRC\tMediterranean\tNative American\tNortheast Asian\tNorthern European\tOceanian\tSouthern African\tSoutheast Asian\tSouthwest Asian\tSubsaharan African'  output/out_Q_test_overlap_split300




### for the given test set
cut -f1-2 -d ' ' output/baseline_overlap_split300.fam > output/baseline_overlap_split300.pop.txt
sed 's/.*GRC.*/ /g' output/baseline_overlap_split300.pop.txt | sed 's/[0-9]//g' | cut -f1 -d' ' >  output/baseline_overlap_split300.pop 
# Note this code extract the reference population lines into where it was in the FAM file to POP file. If the individual ID of the given test set in the FAM file does not have 'GRC' as prefix, this code should be changed to any other code which can correctly extract the reference population sample ID from FAM to the corresponding lines in POP file.

# Run ADMIXTURE in supervised approach
~/admixture32 output/baseline_overlap_split300.bed -F 9 -j8
cat output/baseline_overlap_split300.fam | cut -d ' ' -f1-2 > output/baseline_overlap_split300_out_ind_id
sed -i 's/ /\t/g' output/baseline_overlap_split300_out_ind_id
sed -i 's/ /\t/g' output/baseline_overlap_split300.9.Q
paste output/baseline_overlap_split300_out_ind_id output/baseline_overlap_split300.9.Q > output/out_Q_baseline_overlap_split300
sed -i '1 i\Populations\tGRC\tMediterranean\tNative American\tNortheast Asian\tNorthern European\tOceanian\tSouthern African\tSoutheast Asian\tSouthwest Asian\tSubsaharan African'  output/out_Q_baseline_overlap_split300




# To save the disk memory, remove generated files that will no longer be used
rm application_data/test_overlap_split300.pop*
rm application_data/test_overlap_split300.9.*
rm output/baseline_overlap*
rm output/baseline_overlap_split300*
```

#### Execute the R script for model training and prediction
The first argument after script name should be: *out_Q_<the_first_argument>_overlap_<the_third_argument>*

The second argument after script name should be: *out_Q_<the_seconf_argument>_overlap_<the_third_argument>*

The third argument after script name should be the SNPs set: either 'split300' or 'benchmark'

Note that if the user would use benchmark SNPs set, all 'split300' in all files generated above should be replaced to  
```console 
Rscript --vanilla function/run_rf_output.R test baseline split300

```
The output from the script in the format as *<the_second_argument>_<the_third_argument>_qfile.rdata* and *<the_second_argument>_<the_third_argument>_predicted_latlong.csv*

Predicted geographic coordinates for all individuals in the given test set were stored in the csv file

The rdata file can be further analyzed if needed, but since in forensic investigation, the given test set will almost never have the real geographic coordinates, csv file will be the output file the user always uses.











