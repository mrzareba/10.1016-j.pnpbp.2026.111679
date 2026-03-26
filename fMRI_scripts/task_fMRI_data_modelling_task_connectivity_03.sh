# SPECIFY SUBJECTS
# Currently it is gonna run for all the subjects that have their respective subfolders: $(ls ./ | grep sub). The #-ed alternative makes the script run for specified subs.
subjects=$(ls ./ | grep sub)
#subjects='sub-005'

# SPECIFY SMOOTHING - ONLY ONE VALUE IS ENABLED AT A TIME #
smoothie=5

# SPECIFY ROIS FOR PPI
rois='L_sATL_6mm R_sATL_6mm'

# Prior to running the script you need to prepare certain files for every subject:
# (1) A model of BOLD response for (de)convolution: waver -dt 2 -GAM -inline 1@1 > ./${sub}/func/ppi/GammaHR.1D
# (2) A file contrasting TRs for reliving guilt (1) and neutral memories (-1): ./${sub}/func/ppi/${sub}_guilt_vs_neutral_timing.1D
# This requires making a ppi subfolder within the func directory of each subject before running this script.

# Beginning of the between-subjects loop
for sub in ${subjects[@]}

do	

	### Repeating the original task regression analysis, this time without censoring, to create residual time series for a subject
	
	cd ${sub}
	
	# Smoothing with the pre-specified filter after making sure that the variable is treated like a number
	smoothie=$((${smoothie}))

	3dBlurInMask -input ./func/${sub}_guilt_task_MNI_02.nii.gz -mask ./func/${sub}_brainmask.nii -prefix ./func/${sub}_guilt_task_smoothed_03.nii -FWHM ${smoothie}

	# Calculating percent signal change
	3dTstat -prefix ./func/${sub}_guilt_task_mean_04.nii ./func/${sub}_guilt_task_smoothed_03.nii
	3dcalc -a ./func/${sub}_guilt_task_smoothed_03.nii -b ./func/${sub}_guilt_task_mean_04.nii -expr '100*((a-b)/b)' -prefix ./func/${sub}_guilt_signal_change_05.nii
	rm ./func/${sub}_guilt_task_mean_04.nii
	rm ./func/${sub}_guilt_task_smoothed_03.nii
	
	# Preparing in 3dDeconvolve regression matrices for the first-level (subject-level) analysis
	# Inputs include in the current form: 1 csf regressor, 6 motion parameters and 6 motion parameters derivatives
	# Before creation of the denoising matrix, we calculate the number of regressors that will account for the trends in the data $polort_num
	
	num_vol=$(3dinfo ./func/${sub}_guilt_task.nii.gz | grep -oP '(?<=For info on all ).*?(?= sub-bricks,)')
	polort_num=$((1+(2 * ${num_vol} / 150)))
	
    3dDeconvolve -jobs 6 -tout -num_glt 4 -GOFORIT \
	-input ./func/${sub}_guilt_signal_change_05.nii \
	-mask ./func/${sub}_brainmask.nii \
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
	
	rm ./func/results/${sub}_guilt_task_decon.nii.gz
	
	cd ../
	
	### THE END OF ORIGINAL TASK LOOP ANALYSIS
	
	# Loop between ROIs
	for roi in ${rois[@]}

	do
	
		# Extracting mean residual time series from the leftovers of the original task analysis
		3dmaskave -mask ./group_results/task_activity/activity_rois/${roi}.nii -quiet ./${sub}/func/results/${sub}_guilt_task_resid.nii.gz >> ./${sub}/func/ppi/${sub}_${roi}_bold_ts.1D
	
		# Deconvolving the BOLD response to the neuronal data; this step requires creating GammaHR.1D file beforehand
		3dTfitter -RHS ./${sub}/func/ppi/${sub}_${roi}_bold_ts.1D -FALTUNG ./${sub}/func/ppi/GammaHR.1D ./${sub}/func/ppi/${sub}_${roi}_neural_ts  012 0
		
		# Creating psychophysiological interaction on the neural level
		1deval -a ./${sub}/func/ppi/${sub}_${roi}_neural_ts.1D\' -b ./${sub}/func/ppi/${sub}_guilt_vs_neutral_timing.1D -expr 'a*b' > ./${sub}/func/ppi/${sub}_${roi}_neural_int.1D

		# Creating psychophysiological interaction on the BOLD level
		waver -dt 2 -GAM -peak 1 -input ./${sub}/func/ppi/${sub}_${roi}_neural_int.1D -numout 400 > ./${sub}/func/ppi/${sub}_${roi}_bold_int.1D

		# Repeating the original regression analysis, this time accounting for the mean time course of the seed and the PPI term
		
		cd ${sub}
		
        3dDeconvolve -jobs 6 -tout -num_glt 4 -GOFORIT \
	   -input ./func/${sub}_guilt_signal_change_05.nii \
	   -mask ./func/${sub}_brainmask.nii \
	   -polort $polort_num -nodmbase -num_stimts 22 \
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
       -stim_file 21 ./func/ppi/${sub}_${roi}_bold_ts.1D -stim_label 21 ${roi}_ts \
       -stim_file 22 ./func/ppi/${sub}_${roi}_bold_int.1D -stim_label 22 Guilt_vs_neutral_PPI \
	   -gltsym 'SYM: +Guilt_reliving -Neutral_reliving' -glt_label 1 Guilt_v_neutral \
       -gltsym 'SYM: +Distractor_n3 +Distractor_n4 +Distractor_n5' -glt_label 2 Distractor \
	   -gltsym 'SYM: +Guilt_reliving -Distractor_n5' -glt_label 3 Guilt_v_distractor \
       -gltsym 'SYM: +Neutral_reliving -Distractor_n5' -glt_label 4 Neutral_v_distractor \
       -bucket ./func/ppi/${sub}_guilt_ppi_decon.nii.gz -x1D ./func/ppi/${sub}_guilt_ppi_xmat.1D -xjpeg ./func/ppi/${sub}_guilt_ppi_xmat.jpg
	
		3dREMLfit -matrix ./func/ppi/${sub}_guilt_ppi_xmat.1D -input ./func/${sub}_guilt_signal_change_05.nii \
		-mask ./func/${sub}_brainmask.nii \
		-tout -Rbuck ./func/ppi/${sub}_${roi}_guilt_ppi_stat.nii.gz
		
		# Cleaning up files for the next ROI's PPI
		rm ./func/ppi/${sub}_guilt_ppi_xmat.1D
		rm ./func/ppi/${sub}_guilt_ppi_xmat.jpg
		rm ./func/ppi/${sub}_guilt_ppi_decon.nii.gz

		cd ../

	done
	
	# Cleaning up by removing:
	# residual file from the original regression
	rm ./${sub}/func/results/${sub}_guilt_task_resid.nii.gz
	
	# signal percent change time series
	rm ./${sub}/func/${sub}_guilt_signal_change_05.nii

done
