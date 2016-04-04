#test change for git
# Intel compiler options
ifneq ($(CUSTOM),yes)
FC = ifort
XFLAGS = -xHost -I $(NETCDF_ROOT)/include
LIBS = -L $(NETCDF_ROOT)/lib -lnetcdf -lnetcdff
PPFLAG90 = -fpp
PPFLAG77 = -fpp
DEBUGFLAG = -check all -debug all -traceback -fpe0
endif


# Gfortran compiler options
ifeq ($(GFORTRAN),yes)
FC = gfortran
XFLAGS = -O2 -mtune=native -march=native -I $(NETCDF_ROOT)/include
PPFLAG90 = -x f95-cpp-input
PPFLAG77 = -x f77-cpp-input
DEBUGFLAG = -g -Wall -Wextra -fbounds-check -fbacktrace
endif


# Cray compiler options
ifeq ($(CRAY),yes)
FC = ftn
XFLAGS =
PPFLAG90 = -eZ
PPFLAG77 = -eZ
DEBUGFLAG =
endif


# Testing - I/O and fpmodel
ifeq ($(TEST),yes)
XFLAGS += $(DEBUGFLAG)
endif


OBJT = aeroemiss.o aeroread.o setxyz_m.o ccinterp.o readswitch.o jimcc_m.o \
       latltoij_m.o xyzinfo_m.o newmpar_m.o indices_m.o \
       parm_m.o precis_m.o ind_m.o jimco_m.o jim_utils.o nfft_m.o \
       ncread.o ncwrite.o misc.o netcdf_m.o stacklimit.o

aeroemiss :$(OBJT)
	$(FC) $(XFLAGS) $(OBJT) $(LIBS) -o aeroemiss

clean:
	rm *.o *.mod aeroemiss
# This section gives the rules for building oect modules.

.SUFFIXES:.f90

stacklimit.o: stacklimit.c
	cc -c stacklimit.c

.f90.o:
	$(FC) -c $(XFLAGS) $(PPFLAG90) $<
.f.o:
	$(FC) -c $(XFLAGS) $(PPFLAG77) $<

# Remove mod rule from Modula 2 so GNU make doesn't get confused
%.o : %.mod

aeroemiss.o : ccinterp.o
aeroread.o : ccinterp.o netcdf_m.o
ccinterp.o : ccinterp.f90 setxyz_m.o xyzinfo_m.o latltoij_m.o newmpar_m.o precis_m.o
latltoij_m.o : latltoij_m.f90 xyzinfo_m.o newmpar_m.o precis_m.o
setxyz_m.o : setxyz_m.f90 newmpar_m.o indices_m.o parm_m.o precis_m.o ind_m.o xyzinfo_m.o jimco_m.o jimcc_m.o 
xyzinfo_m.o : xyzinfo_m.f90 precis_m.o
newmpar_m.o : newmpar_m.f90 
precis_m.o : precis_m.f90
indices_m.o : indices_m.f90
parm_m.o : parm_m.f90 precis_m.o 
ind_m.o : ind_m.f90 newmpar_m.o 
jimcc_m.o : jimcc_m.f90 parm_m.o precis_m.o 
jimco_m.o : jimco_m.f90 precis_m.o jim_utils.o nfft_m.o 
jim_utils.o : jim_utils.f90 precis_m.o 
nfft_m.o : nfft_m.f90 precis_m.o 
ncread.o : netcdf_m.o
ncwrite.o : netcdf_m.o
