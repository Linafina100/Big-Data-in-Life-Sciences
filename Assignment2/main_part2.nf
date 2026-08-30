#!/usr/bin/env nextflow
/*
========================================================================================
XCMS test workflow
========================================================================================
Analysis Pipeline doing XCMS mass trace detection.
----------------------------------------------------------------------------------------
*/

// Define a process process that does mass trace detection (files are run in parallel)
process process_masstrace_detection_pos_xcms{
  // Label the process
  label 'xcms'
  // Give name to the process showing what is running
  tag "$mzMLFile"
  // Define the output directory (results will be put here). $projectDir is main directory of the project
  publishDir "$projectDir/process_masstrace_detection_pos_xcms_noncentroided"
  // Input channel from the mzML files
  input:
  // It's a file type channel
  file mzMLFile
  // We create two output channel because process_collect_rdata_pos_xcms process needs an input from this process and  process_align_peaks_pos_xcms process needs another input from this process
  output:
  // Both of the channels are file type and they container the processed input file ".rdata" and the original files ".mzML"
  file "${mzMLFile.baseName}.rdata"
  file "${mzMLFile.baseName}.mzML"

  // Here we run the bash command (the command in this case is in a container)
  // I guess you realized that there is a backslash in front of $PWD. That is telling the nextflow that this specific variable ($PWD) is a bash environment variable not the groovy one!
  script:
  """
  /usr/bin/findPeaks.r input=\$PWD/$mzMLFile output=\$PWD/${mzMLFile.baseName}.rdata ppm=5 peakwidthLow=${params.peakwidthLow} peakwidthHigh=${params.peakwidthHigh} \\
  noise=${params.noise} polarity=${params.polarity} realFileName=$mzMLFile sampleClass=sample
  """
}

// Define a process process that combines all the processed mzML files into a single Rdata file
process  process_collect_rdata_pos_xcms{
  label 'xcms'
  tag "A collection of files"
  publishDir "$projectDir/process_collect_rdata_pos_xcms"

  // A "normal" file channel emmits each file at the time but here we need all the files in one place (not one by one).
  // So we use .collect so all the files are emitted as list (not in parallel)
  input:
  file rdata_files
  // We only output only one file that is called "collection_pos"
  output:
  file "collection_pos.rdata"

  // Our script in the bash section "/usr/local/bin/xcmsCollect.r" requires all the files to be concatenated and joint by comma. So here we just join the elements in the list by commma
  script:
  def inputs_aggregated = rdata_files.join(",")
  """
  nextFlowDIR=\$PWD
  /usr/bin/xcmsCollect.r input=$inputs_aggregated output=collection_pos.rdata
  """
}

// a process to fix the retention time drift
process  process_align_peaks_pos_xcms{
  label 'xcms'
  tag "$rdata_files"
  publishDir "$projectDir/process_align_peaks_pos_xcms"

  input:
  file rdata_files
  file rd
  output:
  file "RTcorrected_pos.rdata"
  script:
  def inputs_aggregated = rd.join(",")
  """
  /usr/bin/retCor.r input=\$PWD/$rdata_files output=RTcorrected_pos.rdata method=obiwarp

  """
}

// a process to group the peaks (linking)
process  process_group_peaks_pos_N1_xcms{
  label 'xcms'
  tag "$rdata_files"
  publishDir "$projectDir/process_group_peaks_pos_N1_xcms"

  input:
  file rdata_files
  output:
  file "groupN1_pos.rdata"

  """
  /usr/bin/group.r input=$rdata_files output=groupN1_pos.rdata bandwidth=3  mzwid=5
  """
}

process process_masstrace_detection_pos_OpenMS {
    debug true    
    // Label and publishDir
    label 'openms'
    publishDir "$projectDir/process_masstrace_detection_pos_OpenMS", mode: 'copy'

    input:
    // 1. The first input from the mzML files
    file mzMLFile
    
    // 2. The parameter file that repeats for each mzML file
    each file(featureFinderIni)

    output:
    // The output named 'alignmentProcess' with the .featureXML extension
    file "${mzMLFile.baseName}.featureXML", emit: alignmentProcess

    script:
    // The bash command with our variables injected
    """
    FeatureFinderMetabo -in ${mzMLFile} -out ${mzMLFile.baseName}.featureXML -ini ${featureFinderIni}
    """
}

process process_masstrace_alignment_pos_OpenMS {
    debug true
    memory '10 GB'

    input:
    // Use .collect() in the workflow block to gather all files into this one variable
    file featureXMLFiles
    each file(alignmentIni)

    output:
    // Output all the aligned files from the 'out' folder
    file "out/*.featureXML", emit: LinkerProcess

    script:
    // Take the list of files and join them with spaces.
    def in_files = featureXMLFiles.join(" ")
    
    // Join the output  with " out/" and prepend "out/" to the very first one
    def out_files = "out/" + featureXMLFiles.join(" out/")
    
    """
    mkdir out
    MapAlignerPoseClustering -in ${in_files} -out ${out_files} -ini ${alignmentIni}
    """
}

process process_masstrace_linker_pos_OpenMS {
    debug true
    memory '10 GB'

    input:
    // Takes the aligned files from the previous step
    file featureXMLFiles
    each file(linkerIni)

    output:
    // Outputs just ONE single file
    file "Aggregated.consensusXML", emit: textExport

    script:
    // Use join again for the inputs
    def in_files = featureXMLFiles.join(" ")
    
    """
    FeatureLinkerUnlabeledQT -in ${in_files} -out Aggregated.consensusXML -ini ${linkerIni}
    """
}

process process_masstrace_exporter_pos_OpenMS {
    debug true
    // Publish the final, clean results to a folder so that they can be easily downloaded
    publishDir "$projectDir/Final_Results", mode: 'copy'

    input:
    file consensusXML

    output:
    // The final clean file
    file "Aggregated_clean.csv", emit: out

    script:
    """
    TextExporter -in ${consensusXML} -out Aggregated.csv
    /usr/bin/readOpenMS.r input=Aggregated.csv output=Aggregated_clean.csv
    """
}

workflow{
 // Define channels
 ch_feature_finder_ini = Channel.fromPath("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/FeatureFinder.ini")
 ch_feature_alignment_ini = Channel.fromPath("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/featureAlignment.ini")
 ch_feature_linker_ini = Channel.fromPath("/crex/proj/uppmax2026-1-94/metabolomics/openms_params/featureLinker.ini")

 mzMLFiles = Channel.fromPath("/crex/proj/uppmax2026-1-94/metabolomics/mzMLData/*.mzML")

 // 1. Feature Finder (Runs on each file individually)
 step1_out = process_masstrace_detection_pos_OpenMS(mzMLFiles, ch_feature_finder_ini)

 // 2. Alignment
 step2_out = process_masstrace_alignment_pos_OpenMS(step1_out.alignmentProcess.collect(), ch_feature_alignment_ini)

 // 3. Linker (Takes the output from Step 2)
 step3_out = process_masstrace_linker_pos_OpenMS(step2_out.LinkerProcess, ch_feature_linker_ini)

 // 4. Exporter (Takes the output from Step 3 and gives us the final CSV)
 final_results = process_masstrace_exporter_pos_OpenMS(step3_out.textExport)

}
