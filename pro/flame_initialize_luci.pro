FUNCTION flame_initialize_luci_waverange, science_header, slit_xmm
;
; return the estimated wavelength range for a slit
;

  ; read in grating name
  grating = strtrim(fxpar(science_header, 'GRATNAME'), 2)

  ; read in grating order
  grating_order = strtrim(fxpar(science_header, 'GRATORDE'), 2)

  ; read in camera name
  camera = strtrim(fxpar(science_header, 'CAMERA'), 2)

  ; read central wavelength 
  central_wavelength = fxpar(science_header, 'GRATWLEN')

  ; look up the wavelength range (in um) covered by the detector: -------------------

  ; grating G210
  if (strsplit(grating, /extract))[0] eq 'G210' then case grating_order of
    '2': wavelength_range = 0.328 ; K 
    '3': wavelength_range = 0.202 ; H 
    '4': wavelength_range = 0.150 ; J 
    '5': wavelength_range = 0.124 ; z
    else: message, grating + ': order ' + grating_order + ' not supported'
  endcase
       
  ; grating G200
  if (strsplit(grating, /extract))[0] eq 'G200' then case grating_order of
    '1': wavelength_range = 0.880 ; HK 
    '2': wavelength_range = 0.440 ; zJ 
    else: message, grating + ': order ' + grating_order + ' not supported'
  endcase
       
  ; grating G150
  if (strsplit(grating, /extract))[0] eq 'G150' then case grating_order of
    '2': wavelength_range = 0.533 ; Ks 
    else: message, grating + ': order ' + grating_order + ' not supported'
  endcase
  
  ; check whether no grating has been found 
  if wavelength_range EQ !NULL then message, 'grating ' + grating + ' not supported'

  ; finally, if the camera is not the default N1.8, then scale by the ratio of pixel scales
  if (strsplit(camera, /extract))[0] NE 'N1.8' then $
    if (strsplit(camera, /extract))[0] eq 'N3.75' then wavelength_range *= 0.47 else $
      message, 'camera ' + camera + ' not supported'

; -------------------------------------------------------------------------------------

  ; rough wavelength range; mask is roughly 2*162mm across; x=0mm means centered slit.
  lambda_min = central_wavelength - (162.0 + slit_xmm) / 162.0 * wavelength_range / 2.0
  lambda_max = lambda_min + wavelength_range


  return, [lambda_min, lambda_max]

END


;******************************************************************



PRO flame_initialize_luci_slits, header, pixel_scale=pixel_scale, $
  slit_num=slit_num, slit_name=slit_name, slit_PA=slit_PA, $
  bottom=bottom, top=top, target=target, wavelength_lo=wavelength_lo, wavelength_hi=wavelength_hi, $
  instrument=instrument
;
; read the header of a LUCI science frame
; and for each slit finds or calculate the slit number, name, slit PA, 
; bottom pixel position, top pixel position, target pixel position, 
; and wavelength at the center of the slit
;

  ; only tweakable settings: maximum width in arcsec allowed for science slits. 
  ; slits wider than this value are considered alignment boxes
  maxwidth_arcsec = 2.0

  ; array of structures that will contain the info for each slit
  slit_hdr = []

  i_slit=1
  while fxpar( header, 'TGT' + string(i_slit, format='(I02)')  + 'NAM', missing='NONE' ) NE 'NONE' do begin

    slitnum = string(i_slit, format='(I02)')

    this_slit_hdr = {number : i_slit, $
    name : strtrim( fxpar( header, 'TGT' + slitnum + 'NAM' ), 2), $
    shape : fxpar( header, 'MOS' + slitnum + 'SHA'), $
    width_arcsec : float(fxpar( header, 'MOS' + slitnum + 'WAS')), $
    length_arcsec : float(fxpar( header, 'MOS' + slitnum + 'LAS')), $
    angle : float(fxpar( header, 'MOS' + slitnum + 'PA')), $
    width_mm : float(fxpar(header, 'MOS' + slitnum + 'WMM')), $
    length_mm : float(fxpar(header, 'MOS' + slitnum + 'LMM')), $
    x_mm : float(fxpar(header, 'MOS' + slitnum + 'XPO')), $
    y_mm : float(fxpar(header, 'MOS' + slitnum + 'YPO')) }

    slit_hdr = [ slit_hdr, this_slit_hdr ]

    i_slit++

  endwhile

  ; exclude reference slits
  slit_hdr = slit_hdr( where( strtrim(slit_hdr.name,2) ne 'refslit', /null) )

  ; exclude alignment boxes
  slit_hdr = slit_hdr[where( slit_hdr.width_arcsec LT maxwidth_arcsec, /null) ]

  ; calculate the conversion between arcsec and mm
  mmtoarcsec = median(slit_hdr.length_arcsec/slit_hdr.length_mm)
  

  ; convert from coordinates in mm to coordinates in pixels
  ;---------------------------------------------------------
  N_pixel_y = fxpar(header, 'NAXIS2')

  deltay_arcsec = slit_hdr.y_mm * mmtoarcsec  ; how many arcsec from the mask center; positive going down
  deltay_pixels = deltay_arcsec / pixel_scale ; how many pixels from the mask center; positive going down
  y_pixels = N_pixel_y / 2 - deltay_pixels    ; y-pixel position, usual convention

  ; find the height in pixels of each slit
  slitheight_pixels = slit_hdr.length_arcsec / pixel_scale

  ; output interesting values
  slit_num = slit_hdr.number
  slit_name = slit_hdr.name
  slit_PA = slit_hdr.angle
  bottom = y_pixels - 0.5*slitheight_pixels
  top = y_pixels + 0.5*slitheight_pixels
  target = y_pixels

  ; calculate approximate wavelength range

  ; identify band
  band = strtrim(fxpar(header, 'FILTER2'),2)

  ; identify central wavelength
  central_wavelength = fxpar(header, 'GRATWLEN')

  ; read camera
  camera = fxpar(header, 'CAMERA')

  ; output wavelength range
  wavelength_lo = []
  wavelength_hi = []

  ; rough wavelength range
  for i_slit=0, n_elements(slit_hdr)-1 do begin
    lambda_range = flame_initialize_luci_waverange(header, slit_hdr[i_slit].x_mm)

    ; output wavelength range
    wavelength_lo = [ wavelength_lo, lambda_range[0] ]
    wavelength_hi = [ wavelength_hi, lambda_range[1] ]
  endfor


END




;******************************************************************


PRO flame_initialize_all, fuel=fuel

  ;
  ; part of initialization in common to any instrument
  ;

  ; check and setup directory structure
  if file_test(fuel.intermediate_dir) eq 0 then spawn, 'mkdir ' + fuel.intermediate_dir
  if file_test(fuel.output_dir) eq 0 then spawn, 'mkdir ' + fuel.output_dir

  ; check that the science file exists
  if ~file_test(fuel.science_filelist) then message, 'file ' + fuel.science_filelist + ' not found'

  ; check that the darks file exists
  if strlowcase(fuel.darks_filelist) NE 'none' then $
    if ~file_test(fuel.darks_filelist) then message, 'file ' + fuel.darks_filelist + ' not found'

  ; check that the flats file exists
  if strlowcase(fuel.flats_filelist) NE 'none' then $
    if ~file_test(fuel.flats_filelist) then message, 'file ' + fuel.flats_filelist + ' not found'

  ; check that the dither file exists
  if strlowcase(fuel.dither_filelist) NE 'none' then $
    if ~file_test(fuel.dither_filelist) then message, 'file ' + fuel.dither_filelist + ' not found'

  ; read the science file
  readcol, fuel.science_filelist, science_filenames, format='A'

  ; set the number of science frames
  fuel.N_frames = n_elements(science_filenames)

  ; create file names for corrected science frames
  corrscience_files = strarr(fuel.N_frames)
  for i_frame=0, fuel.N_frames-1 do begin
    components = strsplit( science_filenames[i_frame], '/', /extract)
    out_filename = components[-1] ; keep just the filename
    out_filename = flame_util_replace_string( out_filename, '.fits', '_corr.fits' )
    print, i_frame
    corrscience_files[i_frame] = fuel.intermediate_dir + out_filename
  endfor

  ; save it to fuel
  *fuel.corrscience_files = corrscience_files

END



;******************************************************************



PRO flame_initialize_luci, fuel=fuel
  ;
  ; LUCI-specific routine that initializes the fuel structure after
  ; the user has changed the default values.
  ;

  ; start with the part in common for all instruments
  flame_initialize_all, fuel=fuel

  ; read file name of first frame
  readcol, fuel.science_filelist, science_filenames, format='A'

  ; read FITS header of first frame
  science_header = headfits(science_filenames[0])

  ; read instrument name - useful to discriminate between LUCI1 and LUCI2
  fuel.instrument = strtrim(fxpar(science_header, 'INSTRUME'), 2)

  ; read in grating
  grating = strtrim(fxpar(science_header, 'GRATNAME'), 2)

  ; set resolution (approximate value; assumes a 0.75" slit width)
  if grating eq 'G210 HiRes' then fuel.instrument_resolution = 3700.0 $
    else message, 'Grating ' + string(grating) + ' not supported'
  
  ; determine what band we are in
  fuel.band =  strtrim(fxpar(science_header, 'FILTER2'), 2)

  ; read in the pixel scale 
  fuel.pixel_scale = fxpar(science_header, 'PIXSCALE')  ; arcsec/pixel

  ; read in read-out noise
  fuel.readnoise = fxpar(science_header, 'RDNOISE')   ; e-/read 

  ; read in gain
  fuel.gain = fxpar(science_header, 'GAIN')   ; e-/adu

  ; read central wavelength 
  central_wavelength = fxpar(science_header, 'GRATWLEN')

  ; read camera
  camera = fxpar(science_header, 'CAMERA')


  ; read in the slits parameters from the FITS header
  ; LONGSLIT ---------------------------------------------------------------------
  if fuel.longslit then begin
    ; get the slit edges from the user

    ; rough wavelength range (slit should be central, x ~ 162 mm)
    lambda_range = $
     flame_initialize_luci_waverange(science_header, 162.0)

    ; create slit structure 
    slits = { $
      number:1, $
      name:'longslit', $
      PA:!values.d_nan, $
      approx_bottom:fuel.longslit_edge[0], $
      approx_top:fuel.longslit_edge[1], $
      approx_target:mean(fuel.longslit_edge), $
      approx_wavelength_lo:lambda_range[0], $
      approx_wavelength_hi:lambda_range[1] }

  ; MOS      ---------------------------------------------------------------------
  endif else begin

    flame_initialize_luci_slits, science_header, pixel_scale=fuel.pixel_scale, $
      slit_num=slit_num, slit_name=slit_name, slit_PA=slit_PA, $
      bottom=bottom, top=top, target=target, wavelength_lo=wavelength_lo, wavelength_hi=wavelength_hi, $
      instrument=fuel.instrument

    ; create array of slit structures
    slits = []
    ; trace the edges of the slits using the sky emission lines
    for i_slit=0, n_elements(bottom)-1 do begin

      this_slit = { $
        number:slit_num[i_slit], $
        name:slit_name[i_slit], $
        PA:slit_PA[i_slit], $
        approx_bottom:bottom[i_slit], $
        approx_top:top[i_slit], $
        approx_target:target[i_slit], $
        approx_wavelength_lo:wavelength_lo[i_slit], $
        approx_wavelength_hi:wavelength_hi[i_slit] }

      slits = [slits, this_slit]

    endfor

  endelse

  ; save the slits in the fuel structure - this is the "slits_fromheader" structure, not "slits"!
  *fuel.slits_fromheader = slits


END