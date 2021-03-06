! Conformal Cubic Atmospheric Model
    
! Copyright 2015 Commonwealth Scientific Industrial Research Organisation (CSIRO)
    
! This file is part of the Conformal Cubic Atmospheric Model (CCAM)
!
! CCAM is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! CCAM is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with CCAM.  If not, see <http://www.gnu.org/licenses/>.

!------------------------------------------------------------------------------
    
! This subroutine is to extract (in memory) data from the CMIP5 aerosol dataset.
!

Subroutine getdata(dataout,grid,lsdata,rlld,sibdim,fname,month)

Use ccinterp
use netcdf_m

Implicit None

Integer, intent(in) :: month
Integer, dimension(2), intent(in) :: sibdim
integer, dimension(sibdim(1),sibdim(2)) :: countt
integer, dimension(4,2) :: arrsize
integer, dimension(4) :: ncsize
integer, dimension(1) :: minpos
integer ncstatus,ncid
integer i,j,n,ix,ii,jj,fp,pos,ind,lci,lcj,nface
Real, dimension(sibdim(1),sibdim(2),19), intent(out) :: dataout
real, dimension(sibdim(1),sibdim(2)) :: datatmp
Real, dimension(sibdim(1),sibdim(2)), intent(in) :: grid,lsdata
Real, dimension(sibdim(1),sibdim(2),2), intent(in) :: rlld
Real, dimension(:,:), allocatable :: coverout,tmpout
Real, dimension(2,2) :: emlonlat
real, dimension(:), allocatable :: rlat,dis
real aglon,aglat,alci,alcj,ssum
character(len=*), dimension(13), intent(in) :: fname
character*160, dimension(2) :: varname
logical ltest

dataout=0.

! read size and coordinates
ncstatus=nf_open(fname(2),nf_nowrite,ncid)
If (ncstatus/=nf_noerr) Then
  Write(6,*) "ERROR: Error opening NetCDF file ",trim(fname(2))," (",ncstatus,")"
  Stop
End If
Call getncdims(ncid,ncsize)
Call getnclonlat(ncid,emlonlat)
arrsize=1
arrsize(1:2,2)=ncsize(1:2)
arrsize(4,1)=month
ncstatus=nf_close(ncid)

!--------------------------------------------------------------------      
! allocate arrays    
allocate(coverout(arrsize(1,2),arrsize(2,2)),tmpout(arrsize(1,2),arrsize(2,2)))

Write(6,*) 'Process CMIP5 aerosol datasets'
do j=1,3 ! 1=Anth,2=Shipping,3=Biomass burning
  do n=1,3 ! 1=SO2,BC,OC

    ! read emission array
    fp=(j-1)*3+n
    ncstatus=nf_open(fname(fp+1),nf_nowrite,ncid)
    If (ncstatus/=nf_noerr) Then
      Write(6,*) "ERROR: Error opening NetCDF file ",trim(fname(fp+1))," (",ncstatus,")"
      Stop
    End If 
    write(6,*) "Processing ",trim(fname(fp+1))
    call getncdims(ncid,ncsize)
    if (ncsize(1)/=arrsize(1,2).or.ncsize(2)/=arrsize(2,2)) then
      write(6,*) "ERROR: Grid size mismatch between files"
      stop
    end if

    ! no upper level ship emissions
    if (j==2) then
      ix=1
    else
      ix=2
    end if

    do i=1,ix  ! 1=Level1,2=Upper level

      coverout=0.

      pos=(j-1)*6+(n-1)*2+i
      select case(pos)
        case(1,3,5) ! SO2,BC,OC Anth Level1
          varname(1)='emiss_awb'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          varname(1)='emiss_dom'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          varname(1)='emiss_tra'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          varname(1)='emiss_wst'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          ind=(n-1)*2+1

        case(2,4,6) ! SO2,BC,OC Anth Upper level
          varname(1)='emiss_ene'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          varname(1)='emiss_ind'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          ind=n*2

        case(7,9,11) ! SO2,BC,OC Ship Level1
          varname(1)='emiss_shp'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          ind=(n-1)*2+1

        case(13,15,17) ! SO2,BC,OC Biomass burning level1
          varname(1)='grassfire'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          ind=(n-1)*2+7        

        case(14,16,18) ! SO2,BC,OC Biomass burning upper level
          varname(1)='forestfire'
          varname(2)='kg m-2 s-1'
          Call getmeta(ncid,varname,tmpout,arrsize)
          coverout=coverout+tmpout
          ind=(n-1)*2+8

        case DEFAULT
          write(6,*) "ERROR: Internal error determining emission dataset"
          stop
      end select
      
      datatmp=0.
      countt=0
      
      ! bin tracer
      do jj=1,arrsize(2,2)
        aglat=(emlonlat(2,2)-emlonlat(2,1))*real(jj-1)/real(arrsize(2,2)-1)+emlonlat(2,1)
        do ii=1,arrsize(1,2)
          aglon=(emlonlat(1,2)-emlonlat(1,1))*real(ii-1)/real(arrsize(1,2)-1)+emlonlat(1,1)
          ! find cc grid point
          Call lltoijmod(aglon,aglat,alci,alcj,nface)
          lci = nint(alci)
          lcj = nint(alcj)
          lcj = lcj+nface*sibdim(1)
          ! bin emission
          if ((nint(lsdata(lci,lcj))==1.and.j/=2).or. &
              (nint(lsdata(lci,lcj))==0.and.j==2)) then
            datatmp(lci,lcj)=datatmp(lci,lcj)+coverout(ii,jj)
          end if
          countt(lci,lcj)=countt(lci,lcj)+1
        end do
      end do
  
      ! fill missing values
      do lcj=1,sibdim(2)
        do lci=1,sibdim(1)
          if (countt(lci,lcj)==0) then
            if ((nint(lsdata(lci,lcj))==1.and.j/=2).or. &
                (nint(lsdata(lci,lcj))==0.and.j==2)) then
              aglon=rlld(lci,lcj,1)
              if (aglon<emlonlat(1,1)) aglon=aglon+360.
              if (aglon>emlonlat(1,1)+360.) aglon=aglon-360.
              aglat=rlld(lci,lcj,2)
              ii=nint((aglon-emlonlat(1,1))*real(arrsize(1,2)-1)/(emlonlat(1,2)-emlonlat(1,1)))+1
              if (ii>arrsize(1,2)) ii=ii-arrsize(1,2)
              jj=nint((aglat-emlonlat(2,1))*real(arrsize(2,2)-1)/(emlonlat(2,2)-emlonlat(2,1)))+1
              jj=min(max(jj,1),arrsize(2,2))
              datatmp(lci,lcj)=coverout(ii,jj)
            end if      
            countt(lci,lcj)=1
          end if
        end do
      end do
      
      ! add to other emissions
      dataout(:,:,ind)=dataout(:,:,ind)+datatmp/real(countt)
      
    end do

    ! close nc file
    ncstatus=nf_close(ncid)
    
  end do
end do

! convert so2 to S
dataout(:,:,1)=0.5*dataout(:,:,1)
dataout(:,:,2)=0.5*dataout(:,:,2)
dataout(:,:,7)=0.5*dataout(:,:,7)
dataout(:,:,8)=0.5*dataout(:,:,8)

deallocate(coverout,tmpout)

!--------------------------------------------------------------------
! volcanic emissions
Write(6,*) "Process volcanic emissions"
ncstatus=nf_open(fname(11),nf_nowrite,ncid)
If (ncstatus/=nf_noerr) Then
  Write(6,*) "ERROR: Error opening NetCDF file ",trim(fname(11))," (",ncstatus,")"
  Stop
End If
write(6,*) "Processing ",trim(fname(11))
Call getncdims(ncid,ncsize)
Call getnclonlat(ncid,emlonlat)
arrsize=1
arrsize(1:2,2)=ncsize(1:2)
arrsize(4,1)=1

allocate(coverout(arrsize(1,2),arrsize(2,2)))
coverout=0.
countt=0

varname(1)='field'
varname(2)='kg/yr'
Call getmeta(ncid,varname,coverout,arrsize)

! bin tracer
do jj=1,arrsize(2,2)
  aglat=(emlonlat(2,2)-emlonlat(2,1))*real(jj-1)/real(arrsize(2,2)-1)+emlonlat(2,1)
  do ii=1,arrsize(1,2)
    aglon=(emlonlat(1,2)-emlonlat(1,1))*real(ii-1)/real(arrsize(1,2)-1)+emlonlat(1,1)
    ! find cc grid point
    Call lltoijmod(aglon,aglat,alci,alcj,nface)
    lci = nint(alci)
    lcj = nint(alcj)
    lcj = lcj+nface*sibdim(1)
    ! bin emission
    if (nint(lsdata(lci,lcj))==1) then
      dataout(lci,lcj,16)=dataout(lci,lcj,16)+coverout(ii,jj)
    end if
    countt(lci,lcj)=countt(lci,lcj)+1
  end do
end do
  
! fill missing values
do lcj=1,sibdim(2)
  do lci=1,sibdim(1)
    if (countt(lci,lcj)==0) then
      if (nint(lsdata(lci,lcj))==1) then
        aglon=rlld(lci,lcj,1)
        aglat=rlld(lci,lcj,2)
        if (aglon<emlonlat(1,1)) aglon=aglon+360.
        if (aglon>emlonlat(1,1)+360.) aglon=aglon-360.
        ii=nint((aglon-emlonlat(1,1))*real(arrsize(1,2)-1)/(emlonlat(1,2)-emlonlat(1,1)))+1
        if (ii>arrsize(1,2)) ii=ii-arrsize(1,2)
        jj=nint((aglat-emlonlat(2,1))*real(arrsize(2,2)-1)/(emlonlat(2,2)-emlonlat(2,1)))+1
        jj=min(max(jj,1),arrsize(2,2))
        dataout(lci,lcj,16)=coverout(ii,jj)
      end if      
      countt(lci,lcj)=1
    end if
  end do
end do

ncstatus=nf_close(ncid)
      
! add to other emissions
dataout(:,:,16)=dataout(:,:,16)/real(countt)

! Normalise to 1Tg/yr (note grid is in km)
ssum=sum(dataout(:,:,16))
if ( ssum>0. ) then
  dataout(:,:,16)=dataout(:,:,16)*1.E9/(86400.*365.25*ssum*grid*grid*1.E6)
end if

deallocate(coverout)

!--------------------------------------------------------------------
! process DMS and natural organic emissions
Write(6,*) "Process DMS and natural organic emissions"

ncstatus=nf_open(fname(12),nf_nowrite,ncid)
If (ncstatus.NE.nf_noerr) Then
  Write(6,*) "ERROR: Error opening NetCDF file ",trim(fname(12))," (",ncstatus,")"
  Stop
End If
write(6,*) "Processing ",trim(fname(12))
Call getncdims(ncid,ncsize)
Call getnclonlat(ncid,emlonlat)

allocate(coverout(ncsize(1),ncsize(2)))
allocate(rlat(ncsize(2)),dis(ncsize(2)))
coverout=0.

arrsize=1
arrsize(2,2)=ncsize(2)
varname(1)='latitude'
varname(2)='degrees_north'
Call getmeta(ncid,varname,rlat,arrsize)

arrsize=1
arrsize(1:2,2)=ncsize(1:2)
arrsize(4,1)=month

do n=1,3

  select case(n)
    case(1)
      varname(1)='dmssea'
      varname(2)='conc'
      Call getmeta(ncid,varname,coverout,arrsize)
    case(2)
      varname(1)='dmsterr'
      varname(2)='kg m-2 s-1'
      Call getmeta(ncid,varname,coverout,arrsize)
    case(3)
      varname(1)='natorg'
      varname(2)='kg m-2 s-1'
      Call getmeta(ncid,varname,coverout,arrsize)
  end select

  countt=0

  ! bin tracer
  do jj=1,arrsize(2,2)
    aglat=rlat(jj)
    do ii=1,arrsize(1,2)
      aglon=(emlonlat(1,2)-emlonlat(1,1))*real(ii-1)/real(arrsize(1,2)-1)+emlonlat(1,1)
      ! find cc grid point
      Call lltoijmod(aglon,aglat,alci,alcj,nface)
      lci = nint(alci)
      lcj = nint(alcj)
      lcj = lcj+nface*sibdim(1)
      ! bin emission
      select case(n)
        case(1)
          ltest=nint(lsdata(lci,lcj))==0
        case(2,3)
          ltest=nint(lsdata(lci,lcj))==1
      end select
      if (ltest) then
        dataout(lci,lcj,12+n)=dataout(lci,lcj,12+n)+coverout(ii,jj)
      end if
      countt(lci,lcj)=countt(lci,lcj)+1
    end do
  end do
  
  ! fill missing values
  do lcj=1,sibdim(2)
    do lci=1,sibdim(1)
      if (countt(lci,lcj)==0) then
        select case(n)
          case(1)
            ltest=nint(lsdata(lci,lcj))==0
          case(2,3)
            ltest=nint(lsdata(lci,lcj))==1
        end select
        if (ltest) then
          aglon=rlld(lci,lcj,1)
          aglat=rlld(lci,lcj,2)
          if (aglon<emlonlat(1,1)) aglon=aglon+360.
          if (aglon>emlonlat(1,1)+360.) aglon=aglon-360.
          ii=nint((aglon-emlonlat(1,1))*real(arrsize(1,2)-1)/(emlonlat(1,2)-emlonlat(1,1)))+1
          if (ii>arrsize(1,2)) ii=ii-arrsize(1,2)
          dis=(rlat-aglat)**2
          minpos=minloc(dis)
          jj=minpos(1)
          dataout(lci,lcj,12+n)=coverout(ii,jj)
        end if      
        countt(lci,lcj)=1
      end if
    end do
  end do

  dataout(:,:,12+n)=dataout(:,:,12+n)/real(countt)

end do

ncstatus=nf_close(ncid)
      
deallocate(coverout,rlat,dis)

!--------------------------------------------------------------------
! process Sand, Silt and Clay fraction that can erode for dust emissions
Write(6,*) "Process dust emission datasets"

ncstatus=nf_open(fname(13),nf_nowrite,ncid)
If (ncstatus.NE.nf_noerr) Then
  Write(6,*) "ERROR: Error opening NetCDF file ",trim(fname(13))," (",ncstatus,")"
  Stop
End If
write(6,*) "Processing ",trim(fname(13))
Call getncdims(ncid,ncsize)
Call getnclonlat(ncid,emlonlat)

allocate(coverout(ncsize(1),ncsize(2)))
allocate(rlat(ncsize(2)),dis(ncsize(2)))
coverout=0.

arrsize=1
arrsize(2,2)=ncsize(2)

varname(1)='latitude'
varname(2)='degrees_north'
Call getmeta(ncid,varname,rlat,arrsize)

arrsize=1
arrsize(1:2,2)=ncsize(1:2)
arrsize(4,1)=1

do n=1,3

  select case(n)
    case(1)
      varname(1)='sand'
      varname(2)='none'
      Call getmeta(ncid,varname,coverout,arrsize)
    case(2)
      varname(1)='silt'
      varname(2)='none'
      Call getmeta(ncid,varname,coverout,arrsize)
    case(3)
      varname(1)='clay'
      varname(2)='none'
      Call getmeta(ncid,varname,coverout,arrsize)
  end select

  countt=0

  ! bin tracer
  do jj=1,arrsize(2,2)
    aglat=rlat(jj)
    do ii=1,arrsize(1,2)
      aglon=(emlonlat(1,2)-emlonlat(1,1))*real(ii-1)/real(arrsize(1,2)-1)+emlonlat(1,1)
      ! find cc grid point
      Call lltoijmod(aglon,aglat,alci,alcj,nface)
      lci = nint(alci)
      lcj = nint(alcj)
      lcj = lcj+nface*sibdim(1)
      ! bin emission
      if (nint(lsdata(lci,lcj))==1) then
        dataout(lci,lcj,16+n)=dataout(lci,lcj,16+n)+coverout(ii,jj)
      end if
      countt(lci,lcj)=countt(lci,lcj)+1
    end do
  end do
  
  ! fill missing values
  do lcj=1,sibdim(2)
    do lci=1,sibdim(1)
      if (countt(lci,lcj)==0) then
        if (nint(lsdata(lci,lcj))==1) then
          aglon=rlld(lci,lcj,1)
          aglat=rlld(lci,lcj,2)
          if (aglon<emlonlat(1,1)) aglon=aglon+360.
          if (aglon>emlonlat(1,1)+360.) aglon=aglon-360.
          ii=nint((aglon-emlonlat(1,1))*real(arrsize(1,2)-1)/(emlonlat(1,2)-emlonlat(1,1)))+1
          if (ii>arrsize(1,2)) ii=ii-arrsize(1,2)
          dis=(rlat-aglat)**2
          minpos=minloc(dis)
          jj=minpos(1)
          dataout(lci,lcj,16+n)=coverout(ii,jj)
        end if      
        countt(lci,lcj)=1
      end if
    end do
  end do

  dataout(:,:,16+n)=dataout(:,:,16+n)/real(countt)

end do

ncstatus=nf_close(ncid)
      
deallocate(coverout,rlat,dis)

Write(6,*) "Task complete"

Return
End
