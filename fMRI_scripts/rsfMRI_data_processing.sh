#!/bin/bash

# Before running this script, you need to extract the denoising regressors of interest from the fMRIprep output and save them as ${sub}_denoising_regressors.tsv
# You also need these 3 files to be placed in subject-specific folders: ${sub}_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz (anatomical fMRIprep output), ${sub}_task-rest_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz (functional fMRIprep output), ${sub}_denoising_regressors.tsv (created from the ${sub}_task-rest_desc-confounds_timeseries.tsv files from the functional fMRIprep output)

# Edit subjects
# Currently it is gonna run for all the subjects that have their respective subfolders: $(ls ./ | grep sub). The #-ed alternative makes the script run for specified subs.
subjects=$(ls ./ | grep sub)
#subjects='sub-005'

#Edit part
part=1
# part 1: prepro + ALFF + fALFF
# part 2: resting-state functional connectivity

## The script runs from here

if [[ ${part} == "1" ]]; then

for sub in ${subjects[@]}

do

	#Entering sub directory
	cd ${sub}

	#Resampling anat brainmask to epi resolution
	3dresample -master ${sub}_task-rest_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz -prefix ${sub}_brainmask.nii -input ${sub}_space-MNI152NLin2009cAsym_desc-brain_mask.nii.gz
		
	#Smoothing with a 5mm filter
	3dBlurInMask -input ${sub}_task-rest_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz -FWHM 5 -mask ${sub}_brainmask.nii -prefix ${sub}_smoothed_01.nii.gz

	# Full regression and band-pass filtering for seed-based connectivity and (normalised) ALFF
	3dDeconvolve -input ${sub}_smoothed_01.nii.gz -mask ${sub}_brainmask.nii -polort 0 -ortvec ${sub}_denoising_regressors.tsv baseline -x1D ${sub}_denoising_matrix_full.1D -xjpeg ${sub}_denoising_matrix_full.jpg -bout -bucket ${sub}_full_decon.nii
	rm ${sub}_full_decon.nii
	rm 3dDeconvolve.err
	rm ${sub}_full_decon.REML_cmd
	
	3dTproject -polort 2 -input ${sub}_smoothed_01.nii.gz -mask ${sub}_brainmask.nii -prefix ${sub}_full_denoised.nii.gz -ort ${sub}_denoising_matrix_full.1D -passband 0.01 0.1

	# normalised ALFF calculation
	3dRSFC -no_rs_out -nodetrend -input ${sub}_full_denoised.nii.gz -mask ${sub}_brainmask.nii -band 0 99999 -prefix ${sub}

	3dcalc -a ${sub}_mALFF+tlrc.BRIK -expr 'a' -prefix ${sub}_norm_ALFF.nii
	rm *.BRIK
	rm *.HEAD
	rm *.BRIK.gz
	
	# Polynomial detrending-less regression for fALFF
	3dDeconvolve -input ${sub}_smoothed_01.nii.gz -mask ${sub}_brainmask.nii -polort 0 -ortvec ${sub}_denoising_regressors.tsv baseline -x1D ${sub}_denoising_matrix_partial.1D -xjpeg ${sub}_denoising_matrix_partial.jpg -bout -bucket ${sub}_partial_decon.nii
	rm ${sub}_partial_decon.nii
	rm 3dDeconvolve.err
	rm ${sub}_partial_decon.REML_cmd

	# fALFF calculation
	3dRSFC -no_rs_out -nodetrend -ort ${sub}_denoising_matrix_partial.1D -input ${sub}_smoothed_01.nii.gz -mask ${sub}_brainmask.nii -band 0.01 0.1 -prefix ${sub}

	# normalised fALFF calculation
	mean_fALFF=$(3dmaskave -mask ${sub}_brainmask.nii -quiet -mrange 1 1 ${sub}_fALFF+tlrc.BRIK)
	3dcalc -a ${sub}_fALFF+tlrc.BRIK -expr a/$mean_fALFF -prefix ${sub}_norm_fALFF.nii
	
	rm *.BRIK
	rm *.HEAD
	
	# Leaving sub directory
	cd ../

done

elif [[ ${part} == "2" ]]; then

for sub in ${subjects[@]}

do

	# Extracting time-series from ROIs
	3dmaskave -quiet -mask ./rois/L_sATL_6mm.nii -mrange 1 1 ./${sub}/${sub}_full_denoised.nii.gz > ./${sub}/${sub}_L_sATL_ts.1D
	3dmaskave -quiet -mask ./rois/R_sATL_6mm.nii -mrange 1 1 ./${sub}/${sub}_full_denoised.nii.gz > ./${sub}/${sub}_R_sATL_ts.1D

	# Performing seed-based correlations
	3dTcorr1D -pearson -Fisher -mask ./${sub}/${sub}_brainmask.nii -prefix ./${sub}/${sub}_L_sATL_corr.nii ./${sub}/${sub}_full_denoised.nii.gz ./${sub}/${sub}_L_sATL_ts.1D
	3dTcorr1D -pearson -Fisher -mask ./${sub}/${sub}_brainmask.nii -prefix ./${sub}/${sub}_R_sATL_corr.nii ./${sub}/${sub}_full_denoised.nii.gz ./${sub}/${sub}_R_sATL_ts.1D

	# Performing global connectivity calculations for voxels within the mask from one sample t-test	
	3dcalc -a ./${sub}/${sub}_full_denoised.nii.gz -b ./rois/one_sample_t_test_mask.nii -expr 'a*b' -prefix ./${sub}/${sub}_masked_regression_for_task_masked_conn.nii
	3dTcorrMap -input ./${sub}/${sub}_masked_regression_for_task_masked_conn.nii -mask ./rois/one_sample_t_test_mask.nii -Zmean ./${sub}/${sub}_task_masked_global_conn.nii
	
done

fi
