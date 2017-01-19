FUNCTION flame_create_fuel
;
; Creates a default 'fuel' structure that the user can then edit.
; Usage:
; fuel = flame_create_fuel()
;

  ; find the Flame directory and check it exists
  path_to_thisfile = file_which('flame_create_fuel.pro', /include_current_dir)
  data_dir = flame_util_replace_string(path_to_thisfile, 'pro/flame_create_fuel.pro', 'data/')
  if ~file_test(data_dir, /directory) then message, 'data directory not found. Check the flame directory structure.'

  fuel = { $
    science_filelist : 'science.txt', $
    darks_filelist: 'none', $
    flats_filelist: 'none', $
    dither_filelist: 'none', $
    intermediate_dir : 'intermediate/', $
    output_dir: 'output/', $
    startrace_y_pos: [0, 0], $
    reduce_only_oneslit : 0, $
    longslit: 0, $
    longslit_edge: [0,0], $
    instrument: '', $
    instrument_resolution: 0.0, $
    N_frames: 0, $
    slitim_filename : 'slitim.fits', $
    flame_data_dir : data_dir, $
    sky_emission_filename : data_dir + 'sky_emission_model.dat', $
    band : '', $
    linelist_filename: data_dir + 'line_list.dat', $
    pixel_scale : 0.0, $
    readnoise : 0.0, $
    gain : 0.0, $
    xrange_star:[1000, 1200], $
    wavecal_approx_smooth : 5, $
    use_sky_edge : 0, $
    instrument_settings: ptr_new(/allocate_heap), $
    corrscience_files : ptr_new(/allocate_heap), $
    diagnostics : ptr_new(/allocate_heap), $
    slits_fromheader : ptr_new(/allocate_heap), $
    slits : ptr_new(/allocate_heap) $
    }
      

    return, fuel



END