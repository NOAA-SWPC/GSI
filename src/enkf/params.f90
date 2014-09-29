module params
!$$$  module documentation block
!
! module: params                       read namelist for EnKF from file
!                                      enkf.nml.
!
! prgmmr: whitaker         org: esrl/psd               date: 2009-02-23
!
! abstract: This module holds the namelist parameters (and some derived
! parameters) read in from enkf.nml (by the module subroutine
! read_namelist) on each MPI task.
!
! Public Subroutines:
!   read_namelist: initialize namelist parameter defaults, read namelist
!    (over-riding defaults for parameters supplied in namelist), compute
!    some derived parameters.  Sets logical variable params_initialized
!    to .true.
!
! Public Variables: (see comments in subroutine read_namelist)
!
! Modules Used: mpisetup, constants, kinds
!
! program history log:
!   2009-02-23  Initial version.
!
! attributes:
!   language: f95
!
!$$$

use mpisetup
use constants, only: rearth, deg2rad, init_constants, init_constants_derived
use kinds, only: r_single,i_kind
use radinfo, only: adp_anglebc,angord,use_edges,emiss_bc

implicit none
private
public :: read_namelist
!  nsats_rad: the total number of satellite data types to read.
!  sattypes_rad:  strings describing the satellite data type (which form part
!   of the diag* filename).
!  dsis:  strings corresponding to sattypes_rad which correspond to the names
!   in the NCEP global_satinfo file.
!  sattypes_oz :  strings describing the ozone satellite data type (which form
!   part of the diag* filename).
integer(i_kind), public, parameter :: nsatmax_rad = 200
integer(i_kind), public, parameter :: nsatmax_oz = 100
! forecast time for first-guess forecast
integer,public :: nhr_anal=6
character(len=2), public :: charfhr_anal
logical, public :: iau=.false. 
character(len=10), public ::  datestring
character(len=500),public :: datapath
character(len=20), public, dimension(nsatmax_rad) ::sattypes_rad, dsis
character(len=20), public, dimension(nsatmax_oz) ::sattypes_oz
logical, public :: deterministic, sortinc, pseudo_rh,&
                   varqc, huber, cliptracers, readin_localization
integer(i_kind),public ::  iassim_order,nlevs,nanals,nvars,numiter,&
                           nlons,nlats,ndim
integer(i_kind),public :: nsats_rad,nsats_oz
real(r_single),public ::  covinflatemax,covinflatemin,smoothparm,biasvar
real(r_single),public ::  corrlengthnh,corrlengthtr,corrlengthsh
real(r_single),public ::  obtimelnh,obtimeltr,obtimelsh
real(r_single),public ::  zhuberleft,zhuberright
real(r_single),public ::  lnsigcutoffnh,lnsigcutofftr,lnsigcutoffsh,&
               lnsigcutoffsatnh,lnsigcutoffsattr,lnsigcutoffsatsh,&
               lnsigcutoffpsnh,lnsigcutoffpstr,lnsigcutoffpssh
real(r_single),public :: analpertwtnh,analpertwtsh,analpertwttr,sprd_tol,saterrfact
real(r_single),public ::  paoverpb_thresh,latbound,delat,p5delat,delatinv
real(r_single),public ::  latboundpp,latboundpm,latboundmp,latboundmm
real(r_single),public :: boxsize
logical,public :: params_initialized = .true.
! do sat bias correction update.
logical,public :: lupd_satbiasc = .true.
logical,public :: simple_partition = .true.
logical,public :: reducedgrid = .false.
logical,public :: univaroz = .true.
logical,public :: regional = .false.
logical,public :: use_gfs_nemsio = .false.
logical,public :: arw = .false.
logical,public :: nmm = .true.
logical,public :: nmmb = .false.
logical,public :: doubly_periodic = .true.
logical,public :: letkf_flag = .false.
logical,public :: massbal_adjust = .false.

namelist /nam_enkf/datestring,datapath,iassim_order,&
                   covinflatemax,covinflatemin,deterministic,sortinc,&
                   corrlengthnh,corrlengthtr,corrlengthsh,&
                   varqc,huber,nlons,nlats,smoothparm,&
                   readin_localization, zhuberleft,zhuberright,&
                   obtimelnh,obtimeltr,obtimelsh,reducedgrid,&
                   lnsigcutoffnh,lnsigcutofftr,lnsigcutoffsh,&
                   lnsigcutoffsatnh,lnsigcutoffsattr,lnsigcutoffsatsh,&
                   lnsigcutoffpsnh,lnsigcutoffpstr,lnsigcutoffpssh,&
                   analpertwtnh,analpertwtsh,analpertwttr,sprd_tol,&
                   nlevs,nanals,nvars,saterrfact,univaroz,regional,use_gfs_nemsio,&
                   paoverpb_thresh,latbound,delat,pseudo_rh,numiter,biasvar,&
                   lupd_satbiasc,cliptracers,simple_partition,adp_anglebc,angord,&
                   nmmb,iau,nhr_anal,letkf_flag,boxsize,massbal_adjust,use_edges,emiss_bc
namelist /nam_wrf/arw,nmm,doubly_periodic
namelist /satobs_enkf/sattypes_rad,dsis
namelist /ozobs_enkf/sattypes_oz


contains

subroutine read_namelist()
integer i
! have all processes read namelist from file enkf.nml

! defaults
! time (analysis time YYYYMMDDHH)
datestring = "0000000000" ! if 0000000000 will not be used.
! corrlength (length for horizontal localization in km)
corrlengthnh = 2800 
corrlengthtr = 2800 
corrlengthsh = 2800 
! read in localization length scales from an external file.
readin_localization = .false.
! min and max inflation.
covinflatemin = 1.0_r_single
covinflatemax = 1.e30_r_single
! lnsigcutoff (length for vertical localization in ln(p))
lnsigcutoffnh = 2._r_single
lnsigcutofftr = 2._r_single
lnsigcutoffsh = 2._r_single
lnsigcutoffsatnh = -999._r_single ! value for satellite radiances
lnsigcutoffsattr = -999._r_single ! value for satellite radiances
lnsigcutoffsatsh = -999._r_single ! value for satellite radiances
lnsigcutoffpsnh = -999._r_single  ! value for surface pressure
lnsigcutoffpstr = -999._r_single  ! value for surface pressure
lnsigcutoffpssh = -999._r_single  ! value for surface pressure
! ob time localization
obtimelnh = 2800._r_single*1000._r_single/(30._r_single*3600._r_single) ! hours to move 2800 km at 30 ms-1.
obtimeltr = obtimelnh
obtimelsh = obtimelnh
! path to data directory (include trailing slash)
datapath = " " ! mandatory
! tolerance for background check.
! obs are not used if they are more than sqrt(S+R) from mean,
! where S is ensemble variance and R is observation error variance.
sprd_tol = 9.9e31_r_single
! definition of tropics and mid-latitudes (for inflation).
latbound = 25._r_single ! this is where the tropics start
delat = 10._r_single    ! width of transition zone.
! adaptive posterior inflation parameter.
analpertwtnh = 0.0_r_single ! no inflation (1 means inflate all the way back to prior spread)
analpertwtsh = 0.0_r_single
analpertwttr = 0.0_r_single
! if ob space posterior variance divided by prior variance
! less than this value, ob is skipped during serial processing.
paoverpb_thresh = 1.0_r_single! don't skip any obs
! set to to 0 for the order they are read in, 1 for random order, or 2 for
! order of predicted posterior variance reduction (based on prior)
iassim_order = 0 
! use 'pseudo-rh' analysis variable, as in GSI.
pseudo_rh = .false.
! if deterministic is true, use EnSRF w/o perturbed obs.
! if false, use perturbed obs EnKF.
deterministic = .true.
! if deterministic is false, re-order obs to minimize regression erros
! as described in Anderson (2003).
sortinc = .true.
! these are all mandatory.
! nlons and nlats are # of lons and lats
nlons = 0
nlats = 0
! total number of levels
nlevs = 0
! number of ensemble members
nanals = 0
! nvars is number of 3d variables to update.
! for hydrostatic models, typically 5 (u,v,T,q,ozone).
nvars = 5
! background error variance for rad bias coeffs  (used in radbias.f90)
! default is GSI value.
biasvar = 0.1_r_single
! Observation box size for LETKF (deg)
boxsize = 90._r_single

! factor to multiply sat radiance errors.
saterrfact = 1._r_single
! number of times to iterate state/bias correction update.
! (only relevant when satellite radiances assimilated, i.e. nobs_sat>0)
numiter = 1

! varqc parameters
varqc = .false.
huber = .false. ! use huber norm instead of "flat-tail"
zhuberleft=1.e30_r_single
zhuberright=1.e30_r_single
! smoothing paramater for inflation (-1 for no smoothing)
smoothparm = -1
! if true, tracers are clipped to zero when read in, and just
! before they are written out.
cliptracers = .true.

! Initialize satellite files to ' '
sattypes_rad=' '
sattypes_oz=' '
dsis=' '

! read from namelist file, doesn't seem to work from stdin with mpich
open(912,file='enkf.nml',form="formatted")
read(912,nam_enkf)
read(912,satobs_enkf)
read(912,ozobs_enkf)
if (regional) then
  read(912,nam_wrf)
endif
close(912)
  
! find number of satellite files
nsats_rad=0
do i=1,nsatmax_rad
  if(sattypes_rad(i) == ' ') cycle
  nsats_rad=nsats_rad+1
end do
if(nproc == 0)write(6,*) 'number of satellite radiance files used',nsats_rad

! find number of satellite files
nsats_oz=0
do i=1,nsatmax_oz
  if(sattypes_oz(i) == ' ') cycle
  nsats_oz=nsats_oz+1
end do
if(nproc == 0)write(6,*) 'number of satellite ozone files used',nsats_oz


! default value of vertical localization for sat radiances 
! and surface pressure should be same as other data.
if (lnsigcutoffsatnh < 0._r_single) lnsigcutoffsatnh = lnsigcutoffnh
if (lnsigcutoffsattr < 0._r_single) lnsigcutoffsattr = lnsigcutofftr
if (lnsigcutoffsatsh < 0._r_single) lnsigcutoffsatsh = lnsigcutoffsh
if (lnsigcutoffpsnh < 0._r_single) lnsigcutoffpsnh = lnsigcutoffnh
if (lnsigcutoffpstr < 0._r_single) lnsigcutoffpstr = lnsigcutofftr
if (lnsigcutoffpssh < 0._r_single) lnsigcutoffpssh = lnsigcutoffsh
p5delat=0.5_r_single*delat
latboundpp=latbound+p5delat
latboundpm=latbound-p5delat
latboundmp=-latbound+p5delat
latboundmm=-latbound-p5delat
delatinv=1.0_r_single/delat

!! if not performing satellite bias correction update, set iterations to 1
if (.not. (lupd_satbiasc)) then 
   numiter=1
   if (nproc == 0) then
     write(6,*) 'PARAMS: NOT UPDATING BIAS CORRECTION COEFFS, SET NUMBER OF ITERATIONS TO 1'
     write(6,*) 'LUPD_SATBIASC, NUMITER = ',lupd_satbiasc,numiter
   end if
end if

if (nproc == 0) then

   print *,'namelist parameters:'
   print *,'--------------------'
   write(6,nam_enkf)
   print *,'--------------------'

! check for mandatory namelist variables

   if (nlons == 0 .or. nlats == 0 .or. nlevs == 0 .or. nanals == 0) then
      print *,'must specify nlons,nlats,nlevs,nanals in namelist'
      print *,nlons,nlats,nlevs,nanals
      call stop2(19)
   end if
   if (numproc .lt. nanals+1) then
      print *,'total number of mpi tasks must be >= nanals'
      print *,'tasks, nanals = ',numproc,nanals
      call stop2(19)
   endif
   if (datapath == ' ') then
      print *,'need to specify datapath in namelist!'
      call stop2(19)
   end if
   if(regional .and. .not. arw .and. .not. nmm .and. .not. nmmb) then
      print *, 'must select either arw, nmm or nmmb regional dynamical core'
      call stop2(19)
   endif
   if (letkf_flag .and. univaroz) then
     print *,'univaroz is not supported yet in LETKF!'
     call stop2(19)
   end if
   
   print *, trim(adjustl(datapath))
   if (datestring .ne. '0000000000') print *, 'analysis time ',datestring
   print *, nanals,' members'
   
end if

! background forecast time for analysis
write(charfhr_anal,'(i2.2)') nhr_anal
if (nproc .eq. 0) then
  print *,'first-guess forecast hour for analysis = ',charfhr_anal
endif

! total number of 2d grids to update.
if (massbal_adjust) then
   if (regional .or. nmmb) then
      if (nproc .eq. 0) print *,'mass balance adjustment only implemented for GFS'
      massbal_adjust = .false.
      ndim = nlevs*nvars+1 
   else
      if (nproc .eq. 0) print *,'add ps tend as analysis var, so mass balance adjustment can be done'
      ndim = nlevs*nvars+2 ! including surface pressure and ps tendency.
   endif
else
   ndim = nlevs*nvars+1 ! including surface pressure and ps tendency.
endif

call init_constants(.false.) ! initialize constants.
call init_constants_derived()

if (nproc == 0) then
    print *,nvars,'3d vars to update'
    if (massbal_adjust) then
     print *,'total of',ndim,' 2d grids will be updated (including ps and ps tend)'
    else
     print *,'total of',ndim,' 2d grids will be updated (including ps)'
    endif
    if (analpertwtnh > 0) then
       print *,'using multiplicative inflation based on Pa/Pb'
    else if (analpertwtnh < 0) then
       print *,'using relaxation-to-prior inflation'
    else
       print *,'no inflation'
    endif
end if

! rescale covariance localization length
corrlengthnh = corrlengthnh * 1.e3_r_single/rearth
corrlengthtr = corrlengthtr * 1.e3_r_single/rearth
corrlengthsh = corrlengthsh * 1.e3_r_single/rearth

! this var is .false. until this routine is called.
params_initialized = .true.

end subroutine read_namelist

end module params