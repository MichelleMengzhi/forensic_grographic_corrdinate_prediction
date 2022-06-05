# master degree project: a forensic grographic corrdinate prediction pipeline
#### course: degree project
#### credit: 45
#### student: Yuexin Yu
#### Supervisor: Eran Elhaik

This is the README file containing the workflow to construct this forensic geopragic cooridnate prediction pipeline.

The required input are available in *Data* directory.

All required packages in R are listed in packages.R

> Introduction. 

  This is an admixture-based pipeline to predict smaples‘ geographic coordinates in given test set. The pipeline applies the following general workflow:  
  * 1. Extract an AIM set from both training set and test set
  * 2. Calculate portions of pupative ancestral populations of traing set and test set repsectively, by ADMIXTURE in supervised mode.
  * 3. Predict the geographic coordinates for samples in test set based on the model trained by Random Forest using training set.   
  
  
> 1. AADR set data preparation
  Codes here are perfomed in Bash command. [PLINK 1.9](https://www.cog-genomics.org/plink/1.9/) is required. Since some of file sizes here are over the size limit on github, only the result files with the prefix *reich_here_overlap* are provided
  ```console
  # Get overlaps between ancestrial population set and AADR set
  plink --bfile ../Genographic/num_Admixture_reference_pops --extract reich_here.bim --make-bed --out genepool_overlap_SNP --noweb
  
  # keep only overlapped SNPs in AADR set
  plink --bfile reich_here --extract ../Genographic/num_Admixture_reference_pops.bim --make-bed --out reich_here_overlap --noweb
  ```
  
> 2. AIM set curation using AADR set 
Note: Only the final result files (in 2..) is provided in *Data* directory
* 2.1. Randomly split AADR samples into 2 based on a filtration criteria, do 100 times
  The filtration criteria:
  Before data splitting, countires having sample size < 5 should be discarded.
  During splitting, split smaples in each country into 2 sets in same size. If the sample size after splitting < 5, all samples in this country are put into training set. Otherwise, training set and test set will get random samples from this country in same size.
  Codes here are performed in R 4.1.2. 
  ```r
  # load meta
  meta <- read.csv('Data/meta_table') #nrow(meta)=14008
  # load sample tbl
  fam <- read.table('Data/reich_here_overlap.fam')[,2] 
  fam_file <- read.table('Data/reich_here_overlap.fam')
  meta <- meta[which(meta$Version.ID %in% fam),] 

  # remove countries having samples < 5
  ctry_count <- as.data.frame(table(meta$Country))
  smaller_than_five <- ctry_count$Var1[which(ctry_count$Freq<=5)]
  meta <- meta[-which(meta$Country %in% smaller_than_five ),] 
  ctry_count <- ctry_count[-which(ctry_count$Freq<=5),] 


  for(j in 1:100){
  sample_set1 <- c()
  sample_set2 <- c()
  
  # select half of samples from each country
   for(i in 1:nrow(ctry_count)){
     ctry <- ctry_count$Var1[i]
     ctry_sample <- meta$Version.ID[which(meta$Country == ctry)]
     split_size <- ceiling(length(ctry_sample)/2)
     if(split_size >= 5){ # if sample size after splitting < 5, all samples in this country are put into training set
       sample_set1 <- c(sample_set1, sample(ctry_sample, size = split_size))
       sample_set2 <- c(sample_set2, ctry_sample[-which(ctry_sample %in% sample_set1)])
     }else{ # if not, put into 2 sets
       sample_set1 <- c(sample_set1, ctry_sample)
     }
   }
   if(length(sample_set1) + length(sample_set2) == nrow(meta)){ # ensure no sample missing
     reference_sample <- fam_file[which(fam_file$V2 %in% sample_set1),]
     test_sample <- fam_file[which(fam_file$V2 %in% sample_set2),]
      
     # save them into file, ans save to a corresponding directory
     dir.create(paste0('dt',j))
     write.table(reference_sample, file = paste0('dt',j,'/reference_sample'),
                  quote = F, row.names = F, sep = '\t')
     write.table(test_sample, file = paste0('dt',j,'/test_sample'),
                  quote = F, row.names = F, sep = '\t')
   }else{
     message(nrow(reference_sample))
     message(nrow(test_sample))
     stop(paste0('In iteration ',j,', the sum of reference sample size and test sample size is not equal to the size of Reich dataset'))
   }
  
  
  }

  ```
  
  * 2.2. For each set of split AADR training and test sets:
  All R code in section 2.2. can be in one R file *ref_pipeline.R*, and run with arugument passing through this script in Bash command such as:
  (Note that *<num>* represents *the number of current set from 100 runs*)
  ``` console
  Rscript --vanilla ref_pipeline.R <num>
  ```
  In ref_pipeline.R, start with:
  ```r
  args <- commandArgs(trailingOnly=TRUE)
  ii <- args[1]
  setwd(paste0('dt',ii))
  ```
  to navigate to the directory having split sample sets in the number of current set from 100 runs.
     + 2.2.1. Extract samples for training set and test set
     Codes here are performed in R. PLINK 1.9 is required. 
     ```r
     system('plink --bfile ../../reich_here_overlap --keep reference_sample --make-bed --out reference_reich --noweb')
     system('plink --bfile ../../reich_here_overlap --keep test_sample --make-bed --out test_reich --noweb')

     ```
     + 2.2.2. Prepare training set + run ADMIXTURE in supervised mode for training set
    Codes here are performed in R. Both [PLINK 1.07](https://zzz.bwh.harvard.edu/plink/download.shtml) and PLINK 1.9 are required.
    ```r
    system('sh baseline_preparation')
    ```
    where *baseline_preparation*:
    (Note that ADMIXTURE is required, and is prepared in main page named as *admixture32*)
    ```console
    # since the coding of base is different for AADR set and ancestral population set, convert the base in AADR set
~/bin/plink-1.07-x86_64/plink --bfile reference_reich --allele1234 --make-bed --out reference_reich_qc --noweb

# try to merge training set with ancestral population set, will get an error due to different allelic location in 2 sets, will automatically generate a .missno file
plink --bfile reference_reich_qc --bmerge ../../genepool_overlap.bed ../../genepool_overlap.bim ../../genepool_overlap.fam  --make-bed --out baseline_overlap --noweb --allow-no-sex

# remove SNPs in different alleleic location
plink --bfile ../../genepool_overlap --exclude genepool_overlap_missnp --make-bed --out genepool_overlap_qcplink --bfile reference_reich_qc --exclude reference_reich_qc_missnp --make-bed --out reich_here_qc2

### To avoid error in ADMIXTURE due to some of samples having all SNPs missing, do quality control for the set
# Calculate missing rate 
plink --bfile baseline_overlap --missing --out baseline_overlap --noweb

# Get the number of SNPs in baseline_overlap
wc -l baseline_overlap.bim # to get the number of SNPs in baseline_overlap

# Get samples having all SNPs missing
cat baseline_overlap.imiss  | awk '{if($4==109627) print $2}' >  baseline_overlap_missing_all_SNPs 

# Remove collected samples
cat baseline_overlap.fam | grep -wEf baseline_overlap_missing_all_SNPs > baseline_overlap_removeIndividual.txt  
plink --bfile baseline_overlap --remove baseline_overlap_removeIndividual.txt --noweb --allow-no-sex --make-bed --out baseline_overlap_qc

# Generate population  file for ADMIXTURE in supervised mode
cut -f1-2 -d ' ' baseline_overlap_qc.fam > baseline_overlap_qc.pop.txt
printf '%.0s\n' {1..1756}  > baseline_overlap_qc.pop
cat baseline_overlap_qc.pop.txt | grep -E 'NorthEastAsian|Mediterranean|SouthAfrican|SouthWestAsian|NativeAmerican|Oceanian|SouthEastAsian|NorthernEuropean|SubsaharanAfrican' | cut -f1 -d' ' >> baseline_overlap_qc.pop
  
# Generate population  file for ADMIXTURE in supervised mode
cut -f1-2 -d ' ' baseline_overlap_qc.fam > baseline_overlap_qc.pop.txt
printf '%.0s\n' {1..1756}  > baseline_overlap_qc.pop
cat baseline_overlap_qc.pop.txt | grep -E 'NorthEastAsian|Mediterranean|SouthAfrican|SouthWestAsian|NativeAmerican|Oceanian|SouthEastAsian|NorthernEuropean|SubsaharanAfrican' | cut -f1 -d' ' >> baseline_overlap_qc.pop

# Run ADMIXTURE in supervised mode
../admixture32 baseline_overlap_qc.bed -F 9 -j8

# Add header to Q file generated from ADMIXTURE
cat baseline_overlap_qc.fam | cut -d ' ' -f1-2 > training_out_ind_id
sed -i 's/ /\t/g' training_out_ind_id
sed -i 's/ /\t/g' baseline_overlap.9.Q
paste training_out_ind_id baseline_overlap.9.Q > out_Q_training_baseline
sed -i '1 i\Populations\tGRC\tMediterranean\tNative American\tNortheast Asian\tNorthern European\tOceanian\tSouthern African\tSoutheast Asian\tSouthwest Asian\tSubsaharan African'  out_Q_training_baseline  
    ```
  
  + 2.2.3. Model training for training set
  ```r
  
  ```


