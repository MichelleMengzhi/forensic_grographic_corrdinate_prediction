rf_model_training_train_test <- function(qfile_train_nogp_popFilter, qfile_test_nogp_popFilter, tag){
  # A pipeline to 
  # 1. run model training by random forest and prediction
  # 2. save predicted latitude and longitude, as well as mean R2 for trained model 
  
  # @qfile_train_nogp_popFilter: The data frame of training set, having sample names, corresponding ancestral population portion calculations, sample's latitude and longitude, GRC, as well as country 
  # @qfile_test_nogp_popFilter: The data frame of test set, having sample names, corresponding ancestral population portion calculations, and GRC
  # @tag: a list, 
  #       element 1: ind i.e. the short name of the given test set
  #       element 2: ite i.e. SNPs set (benchmark/split300)
  
  if(ncol(qfile_train_nogp_popFilter) != ncol(qfile_test_nogp_popFilter)){
    stop(paste('num of columns in train and test is not equal for case', tag[[1]]))
  }
  
  # prepare coastline data for the adjustment of predicted geographic coordinate
  coastlines <- cbind("x"  = maps::SpatialLines2map(rworldmap::coastsCoarse)$x ,"y" =maps::SpatialLines2map(rworldmap::coastsCoarse)$y)
  coastlines <- coastlines[complete.cases(coastlines),]
  coastlines <- coastlines[coastlines[,1] < 180 ,]
  
  # extract columns used for model training
  gp <- colnames(qfile_train_nogp_popFilter)[-c(1,2,12,13,14)]
  
  # random forest model training and prediction
  start_time <- Sys.time()
  source('function/rf_latlong.R')
  run_rlt <-rf_latlong(training = qfile_train_nogp_popFilter, 
                       testing = qfile_test_nogp_popFilter,
                       variables = gp, coast=coastlines)
  testPreds <- run_rlt[[1]]

  end_time <- Sys.time()
  time_for_testPreds <- end_time- start_time
  message(time_for_testPreds)
  
  # write mean R2 value into a file
  system(paste0("echo '",tag[[1]],"_",tag[[2]],",",r2,"' >> mean_R2"))
  
  # add predicted results to the test set data frame
  add_preds <- cbind(qfile_test_nogp_popFilter,
                     "latPred" = testPreds[[1]],
                     "longPred" = testPreds[[2]] )
  
  add_preds <- add_preds[-which(add_preds$Population %in% c('NorthEastAsian', 'Mediterranean',
                                                                    'SouthAfrican', 'SouthWestAsian',
                                                                    'NativeAmerican', 'Oceanian',
                                                                    'SouthEastAsian', 'NorthernEuropean',
                                                                    'SubsaharanAfrican')), ]
  
  write.csv(cbind(add_preds$Populations, add_preds$GRC, add_preds$latPred, add_preds$longPred), file = paste0(tag[[1]],'_',tag[[2]],'_predicted_latlong.csv'))
  
  
  # save test set data frame
  save(add_preds, file = paste0(tag[[1]],'_',tag[[2]],'_qfile.rdata'))


}
