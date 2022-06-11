args <- commandArgs(trailingOnly=TRUE)
train <- args[1]
test <- args[2]
iteration <- args[3]

message(paste('==========',train,test,ite,'=========='))

qfile_train <- read.table(paste0('output/out_Q_',train,'_overlap_',ite), header = T, sep = '\t')
qfile_test <- read.table(paste0('output/out_Q_',test,'_overlap_',ite), header = T, sep = '\t')

# Add meta information
meta <- read.csv('~/Data/meta_table') 

# for training set
qfile_train_nogp <- qfile_train[-which(qfile_train$Population %in% c('NorthEastAsian', 'Mediterranean',
                                                                     'SouthAfrican', 'SouthWestAsian',
                                                                     'NativeAmerican', 'Oceanian',
                                                                     'SouthEastAsian', 'NorthernEuropean',
                                                                     'SubsaharanAfrican')), ]
qfile_train_nogp$Populations<- as.character(qfile_train_nogp$Populations)
qfile_train_nogp_popFilter <- add_meta_reich(qfile_train_nogp, meta)
qfile_train_nogp_popFilter <- droplevels(qfile_train_nogp_popFilter)
print('qfile_train_nogp_popFilter:')
str(qfile_train_nogp_popFilter)

# for test set
qfile_test_nogp <- qfile_test[-which(qfile_test$Population %in% c('NorthEastAsian', 'Mediterranean',
                                                                  'SouthAfrican', 'SouthWestAsian',
                                                                  'NativeAmerican', 'Oceanian',
                                                                  'SouthEastAsian', 'NorthernEuropean',
                                                                  'SubsaharanAfrican')), ]
qfile_test_nogp$Populations<- as.character(qfile_test_nogp$Populations)
# meta <- openxlsx::read.xlsx('population_metasub.xlsx')
# qfile_test_nogp_popFilter <- add_meta_ref(qfile_test_nogp, meta)
qfile_test_nogp_popFilter <- droplevels(qfile_test_nogp)
print('qfile_test_nogp_popFilter:')
str(qfile_test_nogp_popFilter)
qfile_train_nogp_popFilter$GRC <- as.character(qfile_train_nogp_popFilter$GRC)
if(sum(is.na(qfile_train_nogp_popFilter$longitude)) > 0){
  qfile_train_nogp_popFilter <- qfile_train_nogp_popFilter[-which(is.na(qfile_train_nogp_popFilter$longitude)),]
}
qfile_test_nogp_popFilter$GRC <- as.character(qfile_test_nogp_popFilter$GRC)
if(sum(is.na(qfile_test_nogp_popFilter$longitude)) > 0){
  qfile_test_nogp_popFilter <- qfile_test_nogp_popFilter[-which(is.na(qfile_test_nogp_popFilter$longitude)),]
}

### Model training ###
source('function/rf_model_training_train_test.R')
rf_model_training_train_test(qfile_train_nogp_popFilter, qfile_test_nogp_popFilter, tag = c(train, ite))
