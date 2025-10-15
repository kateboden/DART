#!/usr/bin/env bash 

# CESM caseroot is the first argument to the script

main() {

set -ex

caseroot=$1

dart_build_dir=/glade/u/home/kboden/DART/models/MOM6/work
comp_name=OCN
obs_dir=/glade/derecho/scratch/kboden/Obs/reference_merge

echo "DART dart_build_dir" $dart_build_dir

cd $caseroot
get_cesm_info

cd $rundir

get_model_time_from_filename

get_obs_sequence

setup_dart_input_nml

#setup_template_files

#config_inflation

run_filter

date_stamp_output

cleanup

}


#-------------------------------
# Functions
#-------------------------------

#-------------------------------
# info needed from CESM
# This info is avaiable in the python case object
#  it would be good to have the case passed to _do_assimilate
#  in case_run.py
#-------------------------------
get_cesm_info() {
   
exeroot=$(./xmlquery EXEROOT --value) 
rundir=$(./xmlquery RUNDIR --value)
assimilate=$(./xmlquery DATA_ASSIMILATION_$comp_name --value)
ensemble_size=$(./xmlquery NINST_$comp_name --value)
case=$(./xmlquery CASE --value)
   
}


#-------------------------------
# get the model time from the filename
#  used to get the correct obs_seq.out
#-------------------------------
get_model_time_from_filename() {

latest_pointer=$(ls rpointer* | sort | tail -n 1)
date=$(echo "$latest_pointer" | rev | cut -d'.' -f1 | rev)
year=$(echo $date | cut -d '-' -f1)
month=$(echo $date | cut -d '-' -f2)
day=$(echo $date | cut -d '-' -f3)
seconds=$(echo $date | cut -d '-' -f4)

echo "model time is $year $month $day $seconds"

obs_filename=obs_seq.0z.${year}${month}${day}
obs_file=${obs_dir}/${year}/${obs_filename}
}

# inflation movement 
#config_inflation() {

# INITIAL SETUP
# We need to run fill_inflation_restart before case.submit
# This would create initial inflation files 

# flavor 5: El Gharamti 2018 (inverse-gamma: spatially and temporally varying)

# inf_falavor                 =      5, 0
# inf_initial_from_restart    = .true., .false.
# inf_sd_initial_from_restart = .true., .false. 

# 1. input_priorinf_mean.nc
# 2. input_priorinf_sd.nc


# INFLATION FUNCTIONALITY starts here

# Here we save inflation for later diagnostics
# cp output_priorinf_mean.nc inf_dir/output_priorinf_mean_${time_stamp}.nc
# cp output_priorinf_sd.nc inf_dir/output_priorinf_sd_${time_stamp}.nc

# Preparing to run filter
# Note that DART first inflates the ensemble, then updates inflation 
# mv output_priorinf_mean.nc input_priorinf_mean.nc
# mv output_priorinf_sd.nc input_priorinf_sd.nc

#}

#-------------------------------
# set filter input.nml options
#-------------------------------
setup_dart_input_nml() {

echo "setting up input.nml for DART" 

# list ocean restart files- one for each ensemble member
latest_date=$(ls rpointer.* | awk -F. '{print $3}' | sort -r | head -n1)
cat rpointer.ocn_*$latest_date > filter_input_list.txt
cp filter_input_list.txt  filter_output_list.txt

# Store MOM6 nml so it is not overwritten by dart input.nml
mv input.nml input.nml.mom6
cp $dart_build_dir/input.nml $rundir/input.nml
}

#-------------------------------
# set template files for filter
# restart, static, ocean_geometry filenames depend on the case
#-------------------------------
setup_template_files() {

ln -sf $(head -1 filter_input_list.txt) mom6.r.nc

ln -sf $(ls $case.mom6.h.static* | head -1) mom6.static.nc

ln -sf $(ls $case.mom6.h.ocean_geometry* | head -1) ocean_geometry.nc
}

#-------------------------------
# grab the observation sequence file
#-------------------------------
get_obs_sequence() {

echo "grab obs_seq.out" $obs_file

ln -sf $obs_file obs_seq.out
}

#-------------------------------
# run filter
#-------------------------------
run_filter() {

echo "running filter"
if [ "$assimilate" = TRUE ]; then
   mpibind "$exeroot"/filter
fi

}

#-------------------------------
# append timestamp to filter output
#-------------------------------
date_stamp_output() {

mv obs_seq.final "$case".obs_seq.final.${YYYYMMDD}
mv dart_log.out "$case".dart_log.out.${YYYYMMDD}
mv dart_log.nml "$case".dart_log.nml.${YYYYMMDD}

# possible dart output files:
netcdf=(\
"preassim_mean.nc"           "preassim_sd.nc" \
"preassim_priorinf_mean.nc"  "preassim_priorinf_sd.nc" \
"preassim_postinf_mean.nc"   "preassim_postinf_sd.nc" \
"postassim_mean.nc"          "postassim_sd.nc" \
"postassim_priorinf_mean.nc" "postassim_priorinf_sd.nc" \
"postassim_postinf_mean.nc"  "postassim_postinf_sd.nc" \
"output_mean.nc"             "output_sd.nc" \
"output_priorinf_mean.nc"    "output_priorinf_sd.nc" \
"output_postinf_mean.nc"     "output_postinf_sd.nc")

for file in ${netcdf[@]}; do
  if [ -f $file ]; then
     mv "$file" "$case"."$file".${YYYYMMDD}
  fi
done

}


#-------------------------------
# cleanup
# restore mom6 input.nml for next cycle
#-------------------------------
cleanup() {

echo "TODO: stashing restart files for the next cycle"
mv input.nml.mom6 input.nml

}

#-------------------------------

main "$@"
