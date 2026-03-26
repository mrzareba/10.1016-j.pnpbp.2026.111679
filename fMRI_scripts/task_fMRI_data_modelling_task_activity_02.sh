# READ BEFORE RUNNING! #
# The script should be run after task_fMRI_data_preprocessing_script_01.sh. Do not change the location of any of the previous outputs.
# BEFORE RUNNING THE SCRIPT PREPARE SUBJECT-SPECIFIC EVENT TIMINGS (see lines 70-74)

# SPECIFY SUBJECTS #
# Currently it is gonna run for all the subjects that have their respective subfolders: $(ls ./ | grep sub). The #-ed alternative makes the script run for specified subs.
subjects=$(ls ./ | grep sub)
#subjects='sub-005'

# SPECIFY SMOOTHING #
smoothie=5

#### THE CODE RUNS FROM HERE - DO NOT CHANGE IT UNLESS YOU KNOW WHAT YOU ARE DOING ####
------------------------------------------------------------------------------------------
for sub in ${subjects[@]}

do

cd ${sub}

# Making specific folders for the tSNR and results

	mkdir ./func/results
	
	# Calculating tSNR
	3dTstat -tsnr -mask ./func/${sub}_brainmask.nii -prefix ./func/results/${sub}_guilt_task_tnsr.nii ./func/${sub}_guilt_task_MNI_02.nii.gz
	
	# Smoothing with the pre-specified filter after making sure that the variable is treated like a number
	smoothie=$((${smoothie}))

	3dBlurInMask -input ./func/${sub}_guilt_task_MNI_02.nii.gz -mask ./func/${sub}_brainmask.nii -prefix ./func/${sub}_guilt_task_smoothed_03.nii -FWHM ${smoothie}

	# Calculating percent signal change
	3dTstat -prefix ./func/${sub}_guilt_task_mean_04.nii ./func/${sub}_guilt_task_smoothed_03.nii
	3dcalc -a ./func/${sub}_guilt_task_smoothed_03.nii -b ./func/${sub}_guilt_task_mean_04.nii -expr '100*((a-b)/b)' -prefix ./func/${sub}_guilt_signal_change_05.nii
	rm ./func/${sub}_guilt_task_mean_04.nii
	rm ./func/${sub}_guilt_task_smoothed_03.nii
	
	# Preparing in 3dDeconvolve regression matrices for the first-level (subject-level) analysis
	# Inputs include in the current form: 1 csf regressor, 6 motion parameters, 6 motion parameters derivatives and a list of volumes to censor.
	# Before creation of the denoising matrix, we calculate the number of regressors that will account for the trends in the data $polort_num
	
	num_vol=$(3dinfo ./func/${sub}_guilt_task.nii.gz | grep -oP '(?<=For info on all ).*?(?= sub-bricks,)')
	polort_num=$((1+(2 * ${num_vol} / 150)))
	
	# Additionally, we create a motion censoring file based on the framewise displacement calculated for the functional data.
	1d_tool.py -infile ./func/motion/${sub}_guilt_motion_framewise_displacement.1D -set_nruns 1 -show_censor_count -censor_motion 0.5 ./func/motion/${sub}_guilt_motion
	rm ./func/motion/${sub}_guilt_motion_CENSORTR.txt
	rm ./func/motion/${sub}_guilt_motion_enorm.1D
	
	# Running 3dDeconvolve
	3dDeconvolve -jobs 6 -tout -num_glt 4 -GOFORIT \
	-input ./func/${sub}_guilt_signal_change_05.nii \
	-mask ./func/${sub}_brainmask.nii \
	-censor ./func/motion/${sub}_guilt_motion_censor.1D \
	-polort $polort_num -nodmbase -num_stimts 20 \
	-stim_file 1 ./func/motion/${sub}_guilt_motion_demean.1D'[1]' -stim_base 1 -stim_label 1 roll_01 \
	-stim_file 2 ./func/motion/${sub}_guilt_motion_demean.1D'[2]' -stim_base 2 -stim_label 2 pitch_01 \
	-stim_file 3 ./func/motion/${sub}_guilt_motion_demean.1D'[3]' -stim_base 3 -stim_label 3 yaw_01 \
	-stim_file 4 ./func/motion/${sub}_guilt_motion_demean.1D'[4]' -stim_base 4 -stim_label 4 dS_01 \
	-stim_file 5 ./func/motion/${sub}_guilt_motion_demean.1D'[5]' -stim_base 5 -stim_label 5 dL_01 \
	-stim_file 6 ./func/motion/${sub}_guilt_motion_demean.1D'[6]' -stim_base 6 -stim_label 6 dP_01 \
	-stim_file 7 ./func/motion/${sub}_guilt_motion_deriv.1D'[1]' -stim_base 7 -stim_label 7 roll_02 \
	-stim_file 8 ./func/motion/${sub}_guilt_motion_deriv.1D'[2]' -stim_base 8 -stim_label 8 pitch_02 \
	-stim_file 9 ./func/motion/${sub}_guilt_motion_deriv.1D'[3]' -stim_base 9 -stim_label 9 yaw_02 \
	-stim_file 10 ./func/motion/${sub}_guilt_motion_deriv.1D'[4]' -stim_base 10 -stim_label 10 dS_02 \
	-stim_file 11 ./func/motion/${sub}_guilt_motion_deriv.1D'[5]' -stim_base 11 -stim_label 11 dL_02 \
	-stim_file 12 ./func/motion/${sub}_guilt_motion_deriv.1D'[6]' -stim_base 12 -stim_label 12 dP_02 \
	-stim_file 13 ./func/csf/${sub}_guilt_task_csf_demean.1D -stim_base 13 -stim_label 13 CSF \
	-stim_times 14 ./func/${sub}_guilt_reliving_times.1D 'BLOCK(10,1)' -stim_label 14 Guilt_reliving \
	-stim_times 15 ./func/${sub}_neutral_reliving_times.1D 'BLOCK(10,1)' -stim_label 15 Neutral_reliving \
	-stim_times 16 ./func/${sub}_guilt_response_times.1D 'BLOCK(4,1)' -stim_label 16 Guilt_response \
	-stim_times 17 ./func/${sub}_neutral_response_times.1D 'BLOCK(4,1)' -stim_label 17 Neutral_response \    
	-stim_times 18 ./func/${sub}_distractor_n3_times.1D 'BLOCK(6,1)' -stim_label 18 Distractor_n3 \
	-stim_times 19 ./func/${sub}_distractor_n4_times.1D 'BLOCK(8,1)' -stim_label 19 Distractor_n4 \
	-stim_times 20 ./func/${sub}_distractor_n5_times.1D 'BLOCK(10,1)' -stim_label 20 Distractor_n5 \
	-gltsym 'SYM: +Guilt_reliving -Neutral_reliving' -glt_label 1 Guilt_v_neutral \
	-gltsym 'SYM: +Distractor_n3 +Distractor_n4 +Distractor_n5' -glt_label 2 Distractor \
	-gltsym 'SYM: +Guilt_reliving -Distractor_n5' -glt_label 3 Guilt_v_distractor \
	-gltsym 'SYM: +Neutral_reliving -Distractor_n5' -glt_label 4 Neutral_v_distractor \
	-bucket ./func/results/${sub}_guilt_task_decon.nii.gz -x1D ./func/results/${sub}_guilt_task_xmat.1D -xjpeg ./func/results/${sub}_guilt_task_xmat.jpg
	
	# Running 3dREMLfit - a regression procedure that accounts for autocorrelations in the data
	
	3dREMLfit -matrix ./func/results/${sub}_guilt_task_xmat.1D -input ./func/${sub}_guilt_signal_change_05.nii \
	-mask ./func/${sub}_brainmask.nii \
	-tout -Rbuck ./func/results/${sub}_guilt_task_stat.nii.gz -Rerrts ./func/results/${sub}_guilt_task_resid.nii.gz
	
	rm ./func/${sub}_guilt_signal_change_05.nii
	rm ./func/results/${sub}_guilt_task_decon.nii.gz

cd ../

done
