# READ BEFORE RUNNING! #
# The script should be executed in the main folder that contains the participants' subfolders. Before running the script please put a subfolder called dcm in the directory of every participant. The dcm folder should contain all the raw images from the scanner.
# The anatomical scan should be collected as the first sequence after localiser. If it is not like this, please modify the following part of prepropart 1: 'Identifying anatomical image based...'
# The pre-requisites for running this script are installation of dcm2niix, AFNI and FSL.

# SPECIFY SUBJECTS #
# Currently it is gonna run for all the subjects that have their respective subfolders: $(ls ./ | grep sub). The #-ed alternative makes the script run for specified subs.

#subjects=$(ls ./ | grep sub)
subjects='sub-077 sub-078 sub-079 sub-1076 sub-1077 sub-1080 sub-1081'

# SPECIFY TASKS #
# Add the name of the tasks that you want to preprocess.
# IMPORTANT! This will work only for the tasks that have already been added to the prepropart 1 of the script.
# If you want to preprocess an additional task, please add respective lines of code that will get it from dicom images to nii format.
# You can base your code based on the explained examples.

tasks='guilt'

# SPECIFY PART OF THE PREPROCESSING #
# Prepropart 1: conversion from dcm to nii, organising the data into a BIDS-like structure (it is not BIDS though!)
# Prepropart 2: skullstripping, warping and segmenting the anatomical image
# Please check anatomical preprocessing visually. Skullstripping and warping @ sub/anat/qc directory. CSF mask @ sub/anat directory.
# Prepropart 3: deleting first 5 volumes for each task to allow for signal equilibrium, preparing fieldmap files, estimation of motion parameters and calculating the matrix for motion correction, despiking, fieldmap estimation
# Check motion parameters:  motion_maxdispl_volbyvol @ sub/func/qc, motion_framewise_displacement @ sub/func/motion.
# Check fieldmap correction visually @ sub/fmap/qc
# Prepropart 4: calculating transformation matrix between the functional and anatomical images, applying motion+distortion+epi2anat+anat2mni transformation matrices in one step
# Check alignment visually @ sub/func/qc: anatSS + unwarped_temp_aligned, anatQQ + MNI_02
# Prepropart 5: CSF time course signal extraction, creating brainmask

prepropart=1

#### THE CODE RUNS FROM HERE - DO NOT CHANGE IT UNLESS YOU KNOW WHAT YOU ARE DOING ####

# ---------------- prepropart 1 -------------------------------
if [[ ${prepropart} == "1" ]]; then

# Between-subject loop starts

for sub in ${subjects[@]}

do

# Creating folders for neuroimages and entering dcm folder
mkdir ${sub}/anat
mkdir ${sub}/func
mkdir ${sub}/fmap

cd ${sub}/dcm

# Running dcm2niix
dcm2niix ./

## Identifying anatomical image based on the fact that IT IS ALWAYS THE SECOND SEQUENCE APPLIED TO THE SUBJECT, i.e. the first one after the localiser.
# Shell is looking first for the .json file that ends with _2, i.e. the second image collected for the participant, and copies it with the right name.
# MODIFY IT IF NEEDED!
anat_json=$(ls *_2.json)
cp $anat_json ${sub}_T1w.json

# The lines below first remove the last 5 signs from the name of the file stored under anat_json, i.e. the .json file extension, and then replaces it with .nii.
# Lastly, it copies the respective image with the right name.
anat_nii=${anat_json::-5}
anat_nii+='.nii'
cp $anat_nii ${sub}_T1w.nii

## Identifying functional sequences based on their names in the scanner

# First we create a list-like variable that will contain the .json files for all the converted images.
secuencias=$(ls ./ | grep .json)

# keyName stores the variable that contains sequence names in the json files.
keyName="SeriesDescription"

# Now we make a loop for all the sequences stored in secuencias. It looks whether the "SeriesDescription" is followed by the name of the sequence that we provided in the scanner.
# An example name of the sequence is HyperMEPI guilt LR.
# MODIFY IF NEEDED.

for secuencia in ${secuencias[@]}

	do

	value=$(grep -s $keyName $secuencia | cut -d ":" -f2-)
	
	if [[ $value == *'HyperMEPI_guilt_LR'* ]]; then
	
		cp ${secuencia} ${sub}_guilt_task.json
	
		secuencia_nii=${secuencia::-5}
		secuencia_nii+='.nii'
		cp $secuencia_nii ${sub}_guilt_task.nii

	elif [[ $value == *'TOPUP_guilt_LR'* ]]; then
	
		cp ${secuencia} ${sub}_guilt_fmap_rl.json
	
		secuencia_nii=${secuencia::-5}
		secuencia_nii+='.nii'
		cp $secuencia_nii ${sub}_guilt_fmap_rl.nii
	
	fi
	
	done

# Now that we have all the files that we need, we are going to clean the dcm folder from unnecessary files, convert & move files to the right folders.
rm _SECUENCIAS_*

cd ../

# dealing with anat files

mv ./dcm/${sub}_T1w.json ./anat/${sub}_T1w.json
mv ./dcm/${sub}_T1w.nii ./anat/${sub}_T1w.nii

# dealing with functional files, looped for each task

for task in ${tasks[@]}

	do
	
	# dealing with task sequence
	mv ./dcm/${sub}_${task}_task.json ./func/${sub}_${task}_task.json
	3dcopy ./dcm/${sub}_${task}_task.nii ./func/${sub}_${task}_task.nii.gz
	rm ./dcm/${sub}_${task}_task.nii
	
	# dealing with rl fieldmap
	mv ./dcm/${sub}_${task}_fmap_rl.json ./fmap/${sub}_${task}_fmap_rl.json
	3dcopy ./dcm/${sub}_${task}_fmap_rl.nii ./fmap/${sub}_${task}_fmap_rl.nii.gz
	rm ./dcm/${sub}_${task}_fmap_rl.nii
	
	done

cd ../

done

# ---------------- prepropart 2 -------------------------------

elif [[ ${prepropart} == "2" ]]; then

# Between-subject loop starts

for sub in ${subjects[@]}

do

	cd ${sub}
	
	# Skullstripping the anatomical image and warping it to MNI space. The warp is going to be used later for the functional image too.
	
    @SSwarper -input ./anat/${sub}_T1w.nii -base MNI152_2009_template_SSW.nii.gz -subid ${sub} -giant_move
	
	mkdir ./anat/qc
	mv ./anat/AM${sub}.jpg ./anat/qc/AM${sub}.jpg
	mv ./anat/MA${sub}.jpg ./anat/qc/MA${sub}.jpg
	mv ./anat/QC_anatQQ.${sub}.jpg  ./anat/qc/QC_anatQQ.${sub}.jpg
	mv ./anat/QC_anatSS.${sub}.jpg ./anat/qc/QC_anatSS.${sub}.jpg

	rm ./anat/anatS.${sub}.nii
	rm ./anat/init_qc_00_overlap_usrc_obase.jpg
	rm ./anat/anatS.${sub}.nii_radrat.1D.dset
	rm ./anat/init_qc_00_overlap_usrc_obase_DEOB.jpg
	rm ./anat/init_qc_00_overlap_usrc_obase_DEOB.txt
	rm ./anat/anatU.${sub}.nii 
	rm ./anat/init_qc_01_nl0.${sub}.jpg
	rm ./anat/init_qc_02_aff.${sub}.jpg
	rm ./anat/anatUA.${sub}.nii
	rm ./anat/anatUAC.${sub}.nii 
	rm ./anat/anat_cp.${sub}.nii
	
	# Segmenting the normalised anatomical image into grey matter, white matter and cerebrospinal fluid (CSF).
	# Creating binary CSF mask with the resolution of the anatomical image. Moving original segmentation files to the 'seg' subfolder.
	
	fast -S 1 -t 1 -o ./anat/${sub}_seg -n 3 ./anat/anatQQ.${sub}.nii
	
	3dcalc -a ./anat/${sub}_seg_pve_0.nii.gz -expr 'ispositive(a-0.99)' -prefix ./anat/${sub}_csf_mask_anat_res.nii
	
	rm ./anat/${sub}_seg_seg.nii.gz
	rm ./anat/${sub}_seg_mixeltype.nii.gz
	rm ./anat/${sub}_seg_pveseg.nii.gz
	
	mkdir ./anat/seg
	
	mv ./anat/${sub}_seg_pve_0.nii.gz ./anat/seg/${sub}_seg_pve_0.nii.gz
	mv ./anat/${sub}_seg_pve_1.nii.gz ./anat/seg/${sub}_seg_pve_1.nii.gz
	mv ./anat/${sub}_seg_pve_2.nii.gz ./anat/seg/${sub}_seg_pve_2.nii.gz

	cd ../

done

echo 'CHECK ANATOMICAL PREPROCESSING VISUALLY FOR EACH SUBJECT. INSTRUCTIONS AT THE TOP OF THE SCRIPT.'

# ---------------- prepropart 3 -------------------------------

elif [[ ${prepropart} == "3" ]]; then

# Between-subject loop starts

for sub in ${subjects[@]}

do

	cd ${sub}

	# Between-task loop starts

	for task in ${tasks[@]}
	
	do
	
	# Extracting the number of volumes acquired in the run of the task (num_vol). Subtracting 1 because AFNI starts indexing with 0.
	# The first five volumes of the task run are deleted to allow for the signal equilibrium. Thus, AFNI copies volumes from the sixth one until the last one.
	num_vol=$(3dinfo ./func/${sub}_${task}_task.nii.gz | grep -oP '(?<=For info on all ).*?(?= sub-bricks,)')
	num_vol_del=$((${num_vol}-1))
	
	3dcalc -a ./func/${sub}_${task}_task.nii.gz[5-$num_vol_del] -expr 'a' -prefix ./func/${sub}_${task}_task_delvol_00.nii
	
	# The first volume of such a task run is copied for future fieldmap estimation using 3dQwarp with the opposite phase encoding direction images.
	3dcalc -a ./func/${sub}_${task}_task_delvol_00.nii[0] -expr 'a' -prefix ./fmap/${sub}_${task}_fmap_pe_congruent.nii
	
	# The sixth volume (first one after signal equilibirum) of the fieldmap run is extracted for future fieldmap estimtation using 3dQwarp with the opposite phase encoding direction images.
	3dcalc -a ./fmap/${sub}_${task}_fmap_rl.nii.gz[5] -expr 'a' -prefix ./fmap/${sub}_${task}_fmap_pe_incongruent.nii

	# Estimating motion parameters and the transformation matrix for motion correction with the first volume (-base) as a reference
	3dvolreg -Fourier -base 0 -dfile ./func/${sub}_${task}_motion.1D -1Dmatrix_save ./func/${sub}_${task}_motion -prefix ./func/${sub}_${task}_task_mc_temp.nii -maxdisp1D ./func/${sub}_${task}_motion_framewise ./func/${sub}_${task}_task_delvol_00.nii

	# EXPLANATORY COMMENT: As you might have noticed, despite the fact we only want to estimate the matrix for motion correction, we are in fact receiving a proper output image from 3dvolreg.
	# This is, however, a dummy image, which we are only using with the sole purpose of making sure all the corrections/transformations are performed in the correct way.
	# The dummy files will be deleted later during the processing stream.

	# Renaming and moving around the files with frame-wise displacement (for use in regression) and volume-by-volume total displacement (quality check)
	mkdir ./func/qc/
	
	mv ./func/${sub}_${task}_motion_framewise ./func/qc/${sub}_${task}_motion_maxdispl_volbyvol.1D
	mv ./func/${sub}_${task}_motion_framewise_delt ./func/${sub}_${task}_motion_framewise_displacement.1D
	
	# Computing de-meaned and derivatives of motion parameters (for use in regression)
	1d_tool.py -infile ./func/${sub}_${task}_motion.1D -set_nruns 1 -demean -write ./func/${sub}_${task}_motion_demean.1D
	1d_tool.py -infile ./func/${sub}_${task}_motion.1D -set_nruns 1 -derivative -demean -write ./func/${sub}_${task}_motion_deriv.1D 
	
	# Moving around the files related to motion parameters
	mkdir ./func/motion
	mv ./func/${sub}_${task}_motion_framewise_displacement.1D ./func/motion/${sub}_${task}_motion_framewise_displacement.1D
	mv ./func/${sub}_${task}_motion.1D ./func/motion/${sub}_${task}_motion.1D
	mv ./func/${sub}_${task}_motion.aff12.1D ./func/motion/${sub}_${task}_motion.aff12.1D
	mv ./func/${sub}_${task}_motion_demean.1D ./func/motion/${sub}_${task}_motion_demean.1D
	mv ./func/${sub}_${task}_motion_deriv.1D ./func/motion/${sub}_${task}_motion_deriv.1D
	
	# Despiking
	3dDespike -NEW -nomask -localedit -prefix ./func/${sub}_${task}_task_despiked_01.nii ./func/${sub}_${task}_task_delvol_00.nii
	rm ./func/${sub}_${task}_task_delvol_00.nii
	
	3dDespike -NEW -nomask -localedit -prefix ./func/${sub}_${task}_task_despiked_temp.nii ./func/${sub}_${task}_task_mc_temp.nii
	rm ./func/${sub}_${task}_task_mc_temp.nii
	
	# Fieldmap (susceptibility distortion) correction
	3dQwarp -plusminus -prefix ./fmap/${sub}_${task}_sdc.nii ./fmap/${sub}_${task}_fmap_pe_congruent.nii ./fmap/${sub}_${task}_fmap_pe_incongruent.nii
	
	# Making a subfolder for quality check of the fieldmap
	mkdir ./fmap/qc
	mv ./fmap/${sub}_${task}_fmap_pe_congruent.nii ./fmap/qc/${sub}_${task}_fmap_pe_congruent.nii
	rm ./fmap/${sub}_${task}_fmap_pe_incongruent.nii
	rm ./fmap/${sub}_${task}_sdc_PLUS.nii
	rm ./fmap/${sub}_${task}_sdc_PLUS_WARP.nii
	mv ./fmap/${sub}_${task}_sdc_MINUS.nii ./fmap/qc/${sub}_${task}_sdc_MINUS.nii
	
	# Applying the fieldmap to the dummy file.
	3dNwarpApply -nwarp ./fmap/${sub}_${task}_sdc_MINUS_WARP.nii -source ./func/${sub}_${task}_task_despiked_temp.nii -prefix ./func/${sub}_${task}_task_unwarped_temp.nii
	
	rm ./func/${sub}_${task}_task_despiked_temp.nii
	
	done

	cd ../

done

echo 'CHECK MOTION PARAMETERS AND FIELDMAP. INSTRUCTIONS AT THE TOP OF THE FILE.'

# ---------------- prepropart 4 -------------------------------

elif [[ ${prepropart} == "4" ]]; then

# Between-subject loop starts

for sub in ${subjects[@]}

do

	cd ${sub}

	# Between-task loop starts

	for task in ${tasks[@]}
	
	do
	
	# Removing fieldmap quality check files
	rm -r ./fmap/qc
	
	# Calculating transformation matrix between the dummy functional data and skull-stripped anatomical image, moving files for the quality check
	align_epi_anat.py -giant_move -ex_mode quiet -deoblique on -anat_has_skull no -cost lpc  -epi_base 0 -epi2anat -tshift off -volreg off -overwrite -suffix _aligned_epi2anat.nii -anat ./anat/anatSS.${sub}.nii -epi ./func/${sub}_${task}_task_unwarped_temp.nii -Allineate_opts -maxscl 1.6

	mv ${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii ./func/qc/${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii
	cp ./anat/anatSS.${sub}.nii ./func/qc/anatSS.${sub}.nii
	rm anatSS.${sub}_aligned_epi2anat.nii_mat.aff12.1D
	mv ${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii_mat.aff12.1D ./func/${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii_mat.aff12.1D
	rm ./func/${sub}_${task}_task_unwarped_temp.nii
	
	# Applying motion, fieldmap, epi2anat & anat2MNI transformation to the despiked task data in one step --- that is finally our data of interest!
	3dNwarpApply -nwarp ./anat/anatQQ.${sub}_WARP.nii ./anat/anatQQ.${sub}.aff12.1D ./func/${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii_mat.aff12.1D ./fmap/${sub}_${task}_sdc_MINUS_WARP.nii ./func/motion/${sub}_${task}_motion.aff12.1D -source ./func/${sub}_${task}_task_despiked_01.nii -prefix ./func/${sub}_${task}_task_MNI_anat_res.nii -master ./anat/anatQQ.${sub}.nii
				
	# For the application of the above transformation the functional data had to be resampled to the grid resolution of the anatomical data.
	# Now to bring it back to the original grid (voxel size), we are extracting original voxel sizes from the unprocessed data and resampling the functional images in MNI space to that resolution.
	
	x_mm=$(3dinfo ./func/${sub}_${task}_task.nii.gz | grep -oP '(?<=[[L]] -step-).*?(?= mm)')
	y_mm=$(3dinfo ./func/${sub}_${task}_task.nii.gz | grep -oP '(?<=[[P]] -step-).*?(?= mm)')
	z_mm=$(3dinfo ./func/${sub}_${task}_task.nii.gz | grep -oP '(?<=[[S]] -step-).*?(?= mm)')
	
	3dresample -dxyz ${x_mm} ${y_mm} ${z_mm} -prefix ./func/${sub}_${task}_task_MNI_02.nii.gz -input ./func/${sub}_${task}_task_MNI_anat_res.nii			

	rm ./func/${sub}_${task}_task_MNI_anat_res.nii	

	# Copying the data to check the results of the normalisation
	cp ./anat/anatQQ.${sub}.nii ./func/qc/anatQQ.${sub}.nii
	cp ./func/${sub}_${task}_task_MNI_02.nii.gz ./func/qc/${sub}_${task}_task_MNI_02.nii.gz
	
	# Making a specific folder for epi2anat matrices, for the tidying purposes
	mkdir ./func/matrices
	mv ./func/${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii_mat.aff12.1D ./func/matrices/${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii_mat.aff12.1
	
	done

	cd ../

done

echo 'PLEASE CHECK ALIGNMENT OF THE FUNCTIONAL AND ANATOMICAL DATA - INSTRUCTIONS AT THE TOP OF THE SCRIPT'

# ---------------- prepropart 5 -------------------------------

elif [[ ${prepropart} == "5" ]]; then

# Between-subject loop starts

for sub in ${subjects[@]}

do

	cd ${sub}

	# Between-task loop starts

	for task in ${tasks[@]}
	
	do
	
	# Cleaning old files
	rm ./func/qc/anatQQ.${sub}.nii
	rm ./func/qc/${sub}_${task}_task_MNI_02.nii.gz
	rm ./func/qc/${sub}_${task}_task_unwarped_temp_aligned_epi2anat.nii
	rm ./func/qc/anatSS.${sub}.nii
	rm ./func/${sub}_${task}_task_despiked_01.nii
	
	# Resampling the CSF mask to the functional data resolution
	3dresample -master ./func/${sub}_${task}_task_MNI_02.nii.gz -input ./anat/${sub}_csf_mask_anat_res.nii -prefix ./anat/${sub}_csf_mask.nii
	rm ./anat/${sub}_csf_mask_anat_res.nii
	
	# Extracting and demeaning the CSF time course
	mkdir ./func/csf
	3dmaskave -quiet -mask ./anat/${sub}_csf_mask.nii -mrange 1 1 ./func/${sub}_${task}_task_MNI_02.nii.gz > ./func/csf/${sub}_${task}_task_csf.1D
	1d_tool.py -infile ./func/csf/${sub}_${task}_task_csf.1D -set_nruns 1 -demean -write ./func/csf/${sub}_${task}_task_csf_demean.1D
	
	# Creating brainmask based on anatomical image
	3dcalc -a ./anat/anatQQ.${sub}.nii -expr 'ispositive(a)' -prefix ./func/${sub}_brainmask_anat_res.nii
	
	# Resampling it to epi resolution
	3dresample -master ./func/${sub}_${task}_task_MNI_02.nii.gz -input ./func/${sub}_brainmask_anat_res.nii -prefix ./func/${sub}_brainmask.nii
	rm ./func/${sub}_brainmask_anat_res.nii
		
	done

	cd ../

done

echo 'Now please process the data using task-specific scripts that you can build using the provided examples'

fi
