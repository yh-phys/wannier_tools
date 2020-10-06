! This subroutine is used to caculate Hamiltonian for
! bulk system .

! History
!        May/29/2011 by Quansheng Wu

subroutine ham_bulk_atomicgauge(k,Hamk_bulk)
   ! This subroutine caculates Hamiltonian for
   ! bulk system with the consideration of the atom's position
   !
   ! History
   !
   !        May/29/2011 by Quansheng Wu
   !  Atomic gauge Guan Yifei 2019
   !  Lattice gauge Hl
   !  Atomic gauge Ha= U* Hl U 
   !  where U = e^ik.wc(i) on diagonal

   use para
   implicit none

   integer :: i1,i2,iR

   ! wave vector in 3d
   real(Dp) :: k(3), kdotr, pos0(3)

   complex(dp) :: factor

   ! Hamiltonian of bulk system
   complex(Dp),intent(out) ::Hamk_bulk(Num_wann, Num_wann)
   complex(dp), allocatable :: mat1(:, :)
   allocate(mat1(Num_wann, Num_wann))

   Hamk_bulk=0d0
   do iR=1, Nrpts
      kdotr= k(1)*irvec(1,iR) + k(2)*irvec(2,iR) + k(3)*irvec(3,iR)
      factor= exp(pi2zi*kdotr)

      Hamk_bulk(:, :)= Hamk_bulk(:, :) &
         + HmnR(:, :, iR)*factor/ndegen(iR)
   enddo ! iR
   
   mat1=0d0
   do i1=1,Num_wann
      pos0=Origin_cell%wannier_centers_direct(:, i1)
      kdotr= k(1)*pos0(1)+ k(2)*pos0(2)+ k(3)*pos0(3)
      mat1(i1,i1)= exp(pi2zi*kdotr)
   enddo
   Hamk_bulk=matmul(conjg(mat1),matmul(Hamk_bulk,mat1))

   ! check hermitcity
   do i1=1, Num_wann
      do i2=1, Num_wann
         if(abs(Hamk_bulk(i1,i2)-conjg(Hamk_bulk(i2,i1))).ge.1e-6)then
            write(stdout,*)'there is something wrong with Hamk_bulk'
            write(stdout,*)'i1, i2', i1, i2
            write(stdout,*)'value at (i1, i2)', Hamk_bulk(i1, i2)
            write(stdout,*)'value at (i2, i1)', Hamk_bulk(i2, i1)
            !stop
         endif
      enddo
   enddo

   return
end subroutine ham_bulk_atomicgauge

subroutine dHdk_atomicgauge(k, velocity_Wannier)
   !> First derivate of H(k); dH(k)/dk
   use para, only : Nrpts, irvec, Origin_cell, HmnR, ndegen, &
       Num_wann, dp, Rcut, pi2zi,  &
      zi, soc, zzero
   implicit none

   !> momentum in 3D BZ
   real(dp), intent(in) :: k(3)

   !> velocity operator in Wannier basis using atomic gauge 
   complex(dp), intent(out) :: velocity_Wannier(Num_wann, Num_wann, 3)

   integer :: iR, i1, i2, i

   real(dp) :: pos1(3), pos2(3), pos_cart(3), pos_direct(3)
   real(dp) :: kdotr, dis
   complex(dp) :: ratio
   real(dp), external :: norm

   velocity_Wannier= zzero
   !> the first atom in home unit cell
   do iR=1,Nrpts
      do i2=1, Num_wann
         pos2= Origin_cell%wannier_centers_direct(:, i2)
         !> the second atom in unit cell R
         do i1=1, Num_wann
            pos1= Origin_cell%wannier_centers_direct(:, i1)
            pos_direct= irvec(:, iR)+ pos2- pos1

            call direct_cart_real(pos_direct, pos_cart)

            dis= norm(pos_cart)
            if (dis> Rcut) cycle

            kdotr=k(1)*pos_direct(1) + k(2)*pos_direct(2) + k(3)*pos_direct(3)
            ratio= exp(pi2zi*kdotr)/ndegen(iR)

            do i=1, 3
               velocity_Wannier(i1, i2, i)=velocity_Wannier(i1, i2, i)+ &
                  zi*pos_cart(i)*HmnR(i1, i2, iR)*ratio
            enddo ! i

         enddo ! i2
      enddo ! i1
   enddo ! iR

   return
end subroutine dHdk_atomicgauge


subroutine ham_bulk_latticegauge(k,Hamk_bulk)
   ! This subroutine caculates Hamiltonian for
   ! bulk system without the consideration of the atom's position
   !
   ! History
   !
   !        May/29/2011 by Quansheng Wu

   use para, only : dp, pi2zi, HmnR, ndegen, nrpts, irvec, Num_wann, stdout
   implicit none

   ! loop index
   integer :: i1,i2,iR
   integer :: nwann

   real(dp) :: kdotr, k(3)

   complex(dp) :: factor

   ! Hamiltonian of bulk system
   complex(Dp),intent(out) ::Hamk_bulk(Num_wann, Num_wann)

   Hamk_bulk=0d0
   do iR=1, Nrpts
      kdotr= k(1)*irvec(1,iR) + k(2)*irvec(2,iR) + k(3)*irvec(3,iR)
      factor= exp(pi2zi*kdotr)

      Hamk_bulk(:, :)=&
         Hamk_bulk(:, :) &
         + HmnR(:, :, iR)*factor/ndegen(iR)
   enddo ! iR

   ! check hermitcity
   do i1=1, Num_wann
      do i2=1, Num_wann
         if(abs(Hamk_bulk(i1,i2)-conjg(Hamk_bulk(i2,i1))).ge.1e-6)then
            write(stdout,*)'there is something wrong with Hamk_bulk'
            write(stdout,*)'i1, i2', i1, i2
            write(stdout,*)'value at (i1, i2)', Hamk_bulk(i1, i2)
            write(stdout,*)'value at (i2, i1)', Hamk_bulk(i2, i1)
            !stop
         endif
      enddo
   enddo

   return
end subroutine ham_bulk_latticegauge



subroutine dHdk_latticegauge(k, vx, vy, vz)
   use para, only : Nrpts, irvec, crvec, Origin_cell, &
      HmnR, ndegen, Num_wann, zi, pi2zi, dp
   implicit none

   !> momentum in 3D BZ
   real(dp), intent(in) :: k(3)

   !> velocity operator using lattice gauge 
   !> which don't take into account the atom's position
   !> this is a nature choice, while maybe not consistent with the symmetry
   complex(dp), intent(out) :: vx(Num_wann, Num_wann)
   complex(dp), intent(out) :: vy(Num_wann, Num_wann)
   complex(dp), intent(out) :: vz(Num_wann, Num_wann)

   integer :: iR

   real(dp) :: kdotr
   complex(dp) :: ratio

   do iR= 1, Nrpts
      kdotr= k(1)*irvec(1,iR) + k(2)*irvec(2,iR) + k(3)*irvec(3,iR)
      ratio= Exp(pi2zi*kdotr)
      vx= vx+ zi*crvec(1, iR)*HmnR(:,:,iR)*ratio/ndegen(iR)
      vy= vy+ zi*crvec(2, iR)*HmnR(:,:,iR)*ratio/ndegen(iR)
      vz= vz+ zi*crvec(3, iR)*HmnR(:,:,iR)*ratio/ndegen(iR)
   enddo ! iR

   return
end subroutine dHdk_latticegauge

subroutine ham_bulk_LOTO(k,Hamk_bulk)
   ! This subroutine caculates Hamiltonian for
   ! bulk system without the consideration of the atom's position
   ! with the LOTO correction for phonon system
   !
   ! History
   !
   !        July/15/2017 by TianTian Zhang

   use para
   implicit none

   ! loop index
   integer :: i1,i2,ia,ib,ic,iR
   integer  :: ii,jj,mm,nn,pp,qq,xx,yy,zz

   real(dp) :: kdotr

   ! wave vector in 2d
   real(Dp) :: k(3)

   ! coordinates of R vector
   real(Dp) :: R(3), R1(3), R2(3)

   ! Hamiltonian of bulk system
   complex(Dp),intent(out) ::Hamk_bulk(Num_wann, Num_wann)

   !> see eqn. (3) in J. Phys.: Condens. Matter 22 (2010) 202201
   complex(Dp),allocatable :: nac_correction(:, :, :)

   complex(dp), allocatable :: mat1(:, :)
   complex(dp), allocatable :: mat2(:, :)
   real(dp) :: temp1(3)=(/0.0,0.0,0.0/)
   real(dp) :: temp2=0.0
   real(dp) :: temp3(30),constant_t
   real(dp) ::A_ii(3)=(/0.0,0.0,0.0/)
   real(dp) ::A_jj(3)=(/0.0,0.0,0.0/)

   !> k times Born charge
   real(dp), allocatable :: kBorn(:, :)

   real(dp) :: nac_q

   allocate(kBorn(Origin_cell%Num_atoms, 3))
   allocate(mat1(Num_wann, Num_wann))
   allocate(mat2(Num_wann, Num_wann))
   allocate(nac_correction(Num_wann, Num_wann, Nrpts))
   mat1 = 0d0
   mat2 = 0d0
   nac_correction= 0d0

   Hamk_bulk=0d0

   !>  add loto splitting term
   temp1(1:3)= (/0.0,0.0,0.0/)
   temp2= 0.0
   if (abs((k(1)**2+k(2)**2+k(3)**2)).le.0.0001)then  !> skip k=0
      k(1)=0.0001d0
      k(2)=0.0001d0
      k(3)=0.0001d0
   endif

   !> see eqn. (3) in J. Phys.: Condens. Matter 22 (2010) 202201
   do qq= 1, 3
      temp1(qq)= k(1)*Diele_Tensor(qq, 1)+k(2)*Diele_Tensor(qq, 2)+k(3)*Diele_Tensor(qq, 3)
   enddo
   temp2= k(1)*temp1(1)+ k(2)*temp1(2)+ k(3)*temp1(3)
   constant_t= 4d0*3.1415926d0/(temp2*Origin_cell%CellVolume)*VASPToTHZ

   do ii=1, Origin_cell%Num_atoms
      do pp=1, 3
         kBorn(ii, pp)=  k(1)*Born_Charge(ii,1,pp)+k(2)*Born_Charge(ii,2,pp)+k(3)*Born_Charge(ii,3,pp)
      enddo
   enddo

   nac_correction= 0d0
   do iR=1, Nrpts
      R(1)=dble(irvec(1,iR))
      R(2)=dble(irvec(2,iR))
      R(3)=dble(irvec(3,iR))
      kdotr=k(1)*R(1) + k(2)*R(2) + k(3)*R(3)

      do ii= 1,Origin_cell%Num_atoms
         do pp= 1, 3
            do jj= 1, Origin_cell%Num_atoms
               do qq= 1,3
                  nac_q= kBorn(jj, qq)*kBorn(ii, pp)*constant_t/sqrt(Atom_Mass(ii)*Atom_Mass(jj))
                  nac_correction((ii-1)*3+pp,(jj-1)*3+qq,iR) = HmnR((ii-1)*3+pp,(jj-1)*3+qq,iR) + dcmplx(nac_q,0)
               enddo  ! qq
            enddo  ! jj
         enddo ! pp
      enddo  ! ii

      Hamk_bulk(:, :)= Hamk_bulk(:, :) &
         + nac_correction(:, :, iR)*Exp(2d0*pi*zi*kdotr)/ndegen(iR)
   enddo ! iR

   ! check hermitcity
   do i1=1, Num_wann
      do i2=1, Num_wann
         if(abs(Hamk_bulk(i1,i2)-conjg(Hamk_bulk(i2,i1))).ge.1e-6)then
            write(stdout,*)'there is something wrong with Hamk_bulk'
            write(stdout,*)'i1, i2', i1, i2
            write(stdout,*)'value at (i1, i2)', Hamk_bulk(i1, i2)
            write(stdout,*)'value at (i2, i1)', Hamk_bulk(i2, i1)
            !stop
         endif
      enddo
   enddo

   deallocate(kBorn)
   deallocate(mat1)
   deallocate(mat2)
   deallocate(nac_correction)
   return
end subroutine ham_bulk_LOTO

subroutine ham_bulk_kp(k,Hamk_bulk)
   ! > construct the kp model at K point of WC system
   ! > space group is 187. The little group is C3h
   ! Sep/10/2018 by Quansheng Wu

   use para, only : Num_wann, dp, stdout, zi
   implicit none

   integer :: i1,i2,ia,ib,ic,iR, nwann

   ! coordinates of R vector
   real(Dp) :: R(3), R1(3), R2(3), kdotr, kx, ky, kz
   real(dp) :: A1, A2, B1, B2, C1, C2, D1, D2
   real(dp) :: m1x, m2x, m3x, m4x, m1z, m2z, m3z, m4z
   real(dp) :: E1, E2, E3, E4

   complex(dp) :: factor, kminus, kplus

   real(dp), intent(in) :: k(3)

   ! Hamiltonian of bulk system
   complex(Dp),intent(out) ::Hamk_bulk(Num_wann, Num_wann)

   if (Num_wann/=4) then
      print *, "Error : in this kp model, num_wann should be 4"
      print *, 'Num_wann', Num_wann
      stop
   endif

   kx=k(1)
   ky=k(2)
   kz=k(3)
   E1= 1.25d0  
   E2= 0.85d0 
   E3= 0.25d0
   E4=-0.05d0

   A1= 0.10d0
   A2= 0.30d0
   B1= 0.05d0
   B2= 0.1d0

   C1= -1.211d0
   C2= 1.5d0
   D1=-0.6d0
   D2= 0.6d0

   m1x= -1.8d0
   m2x= -1.6d0
   m3x=  1.2d0
   m4x=  1.4d0
   m1z= 2d0
   m2z= 3d0
   m3z=-1d0
   m4z=-1d0

   kminus= kx- zi*ky
   kplus= kx+ zi*ky

   Hamk_bulk= 0d0
   !> kp
   Hamk_bulk(1, 1)= E1+ m1x*(kx*kx+ky*ky)+ m1z*kz*kz
   Hamk_bulk(2, 2)= E2+ m2x*(kx*kx+ky*ky)+ m2z*kz*kz
   Hamk_bulk(3, 3)= E3+ m3x*(kx*kx+ky*ky)+ m3z*kz*kz
   Hamk_bulk(4, 4)= E4+ m4x*(kx*kx+ky*ky)+ m4z*kz*kz

   Hamk_bulk(1, 2)=-zi*D1*kplus*kz
   Hamk_bulk(2, 1)= zi*D1*kminus*kz
   Hamk_bulk(3, 4)= zi*D2*kminus*kz
   Hamk_bulk(4, 3)=-zi*D2*kplus*kz

   Hamk_bulk(1, 4)= zi*C1*kz
   Hamk_bulk(2, 3)= zi*C2*kz
   Hamk_bulk(3, 2)=-zi*C2*kz
   Hamk_bulk(4, 1)=-zi*C1*kz

   Hamk_bulk(1, 3)=  A1*kplus+ B1*kminus*kminus !+ D*kplus*kplus*kplus
   Hamk_bulk(2, 4)=  A2*kminus+ B2*kplus*kplus !+ D*kminus*kminus*kminus
   Hamk_bulk(3, 1)= conjg(Hamk_bulk(1, 3))
   Hamk_bulk(4, 2)= conjg(Hamk_bulk(2, 4))

   ! check hermitcity
   do i1=1, Num_wann
      do i2=1, Num_wann
         if(abs(Hamk_bulk(i1,i2)-conjg(Hamk_bulk(i2,i1))).ge.1e-6)then
            write(stdout,*)'there is something wrong with Hamk_bulk'
            write(stdout,*)'i1, i2', i1, i2
            write(stdout,*)'value at (i1, i2)', Hamk_bulk(i1, i2)
            write(stdout,*)'value at (i2, i1)', Hamk_bulk(i2, i1)
            !stop
         endif
      enddo
   enddo

   return
end subroutine ham_bulk_kp

subroutine ham_bulk_coo_densehr(k,nnzmax, nnz, acoo,icoo,jcoo)
   !> This subroutine use sparse hr format
   ! History
   !        Dec/10/2018 by Quansheng Wu
   use para
   implicit none

   real(dp), intent(in) :: k(3)
   integer, intent(in) :: nnzmax
   integer, intent(out) :: nnz
   integer,intent(inout):: icoo(nnzmax),jcoo(nnzmax)
   complex(dp),intent(inout) :: acoo(nnzmax)

   ! loop index
   integer :: i1,i2,ia,ib,ic,iR, iz
   integer :: nwann

   real(dp) :: kdotr

   ! wave vector in 3D BZ
   ! coordinates of R vector
   real(Dp) :: R(3), R1(3), R2(3)

   complex(dp) :: factor

   ! Hamiltonian of bulk system
   complex(Dp), allocatable :: Hamk_bulk(:, :)

   allocate( Hamk_bulk(Num_wann, Num_wann))
   Hamk_bulk= 0d0

   do iR=1, Nrpts
      ia=irvec(1,iR)
      ib=irvec(2,iR)
      ic=irvec(3,iR)

      R(1)=dble(ia)
      R(2)=dble(ib)
      R(3)=dble(ic)
      kdotr=k(1)*R (1) + k(2)*R (2) + k(3)*R (3)
      factor= exp(pi2zi*kdotr)

      Hamk_bulk(:, :)=&
         Hamk_bulk(:, :) &
         + HmnR(:, :, iR)*factor/ndegen(iR)
   enddo ! iR

   !> transform Hamk_bulk into sparse COO format

   nnz= 0
   do i1=1, Num_wann
      do i2=1, Num_wann
         if(abs(Hamk_bulk(i1,i2)).ge.1e-6)then
            nnz= nnz+ 1
            if (nnz>nnzmax) stop 'nnz is larger than nnzmax in ham_bulk_coo_densehr'
            icoo(nnz) = i1
            jcoo(nnz) = i2
            acoo(nnz) = Hamk_bulk(i1, i2)
         endif
      enddo
   enddo

   ! check hermitcity
   do i1=1, Num_wann
      do i2=1, Num_wann
         if(abs(Hamk_bulk(i1,i2)-conjg(Hamk_bulk(i2,i1))).ge.1e-6)then
            write(stdout,*)'there is something wrong with Hamk_bulk'
            write(stdout,*)'i1, i2', i1, i2
            write(stdout,*)'value at (i1, i2)', Hamk_bulk(i1, i2)
            write(stdout,*)'value at (i2, i1)', Hamk_bulk(i2, i1)
         endif
      enddo
   enddo

   return
end subroutine ham_bulk_coo_densehr


subroutine ham_bulk_coo_sparsehr_latticegauge(k,acoo,icoo,jcoo)
   !> This subroutine use sparse hr format
   !> Here we use atomic gauge which means the atomic position is taken into account
   !> in the Fourier transformation
   use para
   implicit none

   real(dp) :: k(3), posij(3)
   integer,intent(inout):: icoo(splen),jcoo(splen)!,splen
   complex(dp),intent(inout) :: acoo(splen)
   complex(dp) :: kdotr, ratio
   integer :: i,j,ir

   do i=1,splen
      ir=hirv(i)
      icoo(i)=hicoo(i)
      jcoo(i)=hjcoo(i)
      posij=irvec(:, ir)
      kdotr=posij(1)*k(1)+posij(2)*k(2)+posij(3)*k(3)
      ratio= exp(pi2zi*kdotr)
      acoo(i)=ratio*hacoo(i)
   end do

   return
end subroutine ham_bulk_coo_sparsehr_latticegauge


subroutine ham_bulk_coo_sparsehr(k,acoo,icoo,jcoo)
   !> This subroutine use sparse hr format
   !> Here we use atomic gauge which means the atomic position is taken into account
   !> in the Fourier transformation
   use para
   implicit none

   real(dp) :: k(3), posij(3)
   integer,intent(inout):: icoo(splen),jcoo(splen)!,splen
   complex(dp),intent(inout) :: acoo(splen)
   complex(dp) :: kdotr, ratio
   integer :: i,j,ir

   do i=1,splen
      ir=hirv(i)
      icoo(i)=hicoo(i)
      jcoo(i)=hjcoo(i)
      posij=irvec(:, ir)+ Origin_cell%wannier_centers_direct(:, jcoo(i))- Origin_cell%wannier_centers_direct(:, icoo(i))
      kdotr=posij(1)*k(1)+posij(2)*k(2)+posij(3)*k(3)
      ratio= exp(pi2zi*kdotr)
      acoo(i)=ratio*hacoo(i)
   end do

   return
end subroutine ham_bulk_coo_sparsehr


subroutine rotation_to_Ham_basis(UU, mat_wann, mat_ham)
   !> this subroutine rotate the matrix from Wannier basis to Hamiltonian basis
   !> UU are the eigenvectors from the diagonalization of Hamiltonian
   !> mat_ham=UU_dag*mat_wann*UU
   use para, only : dp, Num_wann
   implicit none
   complex(dp), intent(in) :: UU(Num_wann, Num_wann)
   complex(dp), intent(in) :: mat_wann(Num_wann, Num_wann)
   complex(dp), intent(out) :: mat_ham(Num_wann, Num_wann)
   complex(dp), allocatable :: UU_dag(:, :), mat_temp(:, :)

   allocate(UU_dag(Num_wann, Num_wann), mat_temp(Num_wann, Num_wann))
   UU_dag= conjg(transpose(UU))

   call mat_mul(Num_wann, mat_wann, UU, mat_temp) 
   call mat_mul(Num_wann, UU_dag, mat_temp, mat_ham) 

   return
end subroutine rotation_to_Ham_basis



