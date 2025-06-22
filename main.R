#Particle in a static field
#Upwards taken to be the positive direction, Euler method
#theta is the angle between the  positive x direction and velocity direction in RADIANS
#Plot of the numerically approximation (blue) vs real (black) trajectory
staticEuler=function(a,b,y0,v0,theta,g,N){
  yprime=function(x,y){
    tan(theta)+(g*(x-a))/((v0*cos(theta))^2) #This is the trajectory equation differentiated with respect to x
  }
  h=(b-a)/N
  l=c(y0) #This will be our sequence of approximated y values
  s=seq(a+h,b,by=h) #This is our sequence of x values
  for (i in 0:N-1){
    l=c(l,l[i]+h*yprime(s[i])) #This is a for loop that approximates the y values via the Euler method
  }
  plot(s,l,type="l",col="blue",xlab="x",ylab="y",main="Simulated trajectory of a particle in a static field using the Euler method")
  lines(s,y0+(s-a-h)*tan(theta)+(g*(s-a-h)^2)/(2*(v0*cos(theta))^2))
  legend("bottomleft",legend=c("Calculated","Euler"),lty=c("solid","solid"),col=c("black","blue"))
}
#This function outputs a graph of y against x, where the Euler method has been used to simulate how y varies with x
staticEuler(1,20,100,10,pi/4,-9.81,30)

#Particle in a static field, Midpoint method
#theta is the angle between the  positive x direction and velocity direction in RADIANS
#Plot of the numerically approximation (green) vs real (black) trajectory
staticMidpoint=function(a,b,y0,v0,theta,g,N){
  y=function(x){
    (x-a)*tan(theta)+(g*(x-a)^2)/(2*(v0*cos(theta))^2) #This is the trajectory equation
  }
  yprime=function(x,y){
    y/(x-a)+(g*(x-a))/(2*(v0*cos(theta))^2) #This is the trajectory equation differentiated
  }
  h=(b-a)/N
  l=c(y0)
  s=seq(a+h,b,by=h)
  for (i in 0:N-1){
    l=c(l,l[i]+h*yprime(s[i]+h/2,y(s[i])+0.5*h*yprime(s[i],y(s[i])))) #This is the midpoint method approximation
  }
  plot(s,l,type="l",col="green",xlab="x",ylab="y",main="Simulated trajectory of a particle in a static field using the Midpoint method")
  lines(s,y0+(s-a-h)*tan(theta)+(g*(s-a-h)^2)/(2*(v0*cos(theta))^2))
  legend("bottomleft",legend=c("Calculated","Midpoint method"),lty=c("solid","solid"),col=c("black","green"))
}
staticMidpoint(1,20,100,10,pi/4,-9.81,30)

#Particle in a static field, Modified Euler method
#Plot of the numerically approximation (yellow) vs real (black) trajectory
staticMod.Euler=function(a,b,y0,v0,theta,g,N){
  y=function(x){
    (x-a)*tan(theta)+(g*(x-a)^2)/(2*(v0*cos(theta))^2)
  }
  yprime=function(x,y){
    y/(x-a)+(g*(x-a))/(2*(v0*cos(theta))^2)
  }
  h=(b-a)/N
  l=c(y0)
  s=seq(a+h,b,by=h)
  for (i in 0:N-1){
    l=c(l,l[i]+0.5*h*(yprime(s[i],y(s[i]))+yprime(s[i+1],y(s[i])+h*yprime(s[i],y(s[i])))))
  }
  plot(s,l,type="l",col="yellow",xlab="x",ylab="y",main="Simulated trajectory of a particle in a static field using the Modified Euler method")
  lines(s,y0+(s-a-h)*tan(theta)+(g*(s-a-h)^2)/(2*(v0*cos(theta))^2))
  legend("bottomleft",legend=c("Calculated","Modified Euler"),lty=c("solid","solid"),col=c("black","yellow"))
}
staticMod.Euler(1,20,100,10,pi/4,-9.81,30)

#Particle in a static field, Runge-Kutta method
#theta is the angle between the  positive x direction and velocity direction in RADIANS
#Plot of the numerically approximation (orange) vs real (black) trajectory
staticRungeKutta=function(a,b,y0,v0,theta,g,N){
  y=function(x){
    (x-a)*tan(theta)+(g*(x-a)^2)/(2*(v0*cos(theta))^2)
  }
  yprime=function(x,y){
    y/(x-a)+(g*(x-a))/(2*(v0*cos(theta))^2)
  }
  h=(b-a)/N
  s=seq(a,b,by=h) #This sequence stays the same
  l=c(y0)
  for(i in 1:N){ #This is different such that we are able to produce a sequence of the correct length for the plot
    K1=h*yprime(s[i],y(s[i]))
    K2=h*yprime(s[i]+h/2,y(s[i])+K1/2)
    K3=h*yprime(s[i]+h/2,y(s[i])+K2/2)
    K4=h*yprime(s[i]+h,y(s[i])+K3)
    l=c(l,y0+y(s[i])+(K1+2*K2+2*K3+K4)/6)
  }
  plot(s,l,type="l",col="orange",xlab="x",ylab="y",main="Simulated trajectory of a particle in a static field using the Runge-Kutta method")
  lines(s,y0+(s-a)*tan(theta)+(g*((s-a)^2)/(2*(v0*cos(theta))^2)))
  legend("bottomleft",legend=c("Calculated","Runge-Kutta"),lty=c("solid","solid"),col=c("black","orange"))
}
staticRungeKutta(1,20,100,10,pi/4,-9.81,30)



#Particle in Earth's gravitational field where g varies with r
#Euler method
G=6.6743015*10^(-11)
M=5.974*10^24 #Mass of Earth
R=6.38*10^6 #This the radius of Earth, the "height" of Earth's surface
complexEuler=function(a,b,y0,v0,theta,N){
  yprime=function(x){
    tan(theta)+(g*(x-a))/(v0*cos(theta))^2
  }
  #Energy conservation test: (no particle mass is involved) energy is conserved if the ratio of initial to final energies equals 1
  h=(b-a)/N
  r=R+y0
  g=-G*M/r^2 #This is our initial value of g
  l=c(y0)
  s=seq(a+h,b,by=h)
  Ea=0.5*v0^2-G*M/r #Initial energy per mass of the particle
  for (i in 0:N-1){
    l=c(l,l[i]+h*yprime(s[i]))
    r=R+l[i+1]
    g=-G*M/r^2
  }
  v=sqrt((v0*cos(theta))^2+(v0*sin(theta)+g*(b-a)/(v0*cos(theta)))^2)
  Eb=0.5*v^2-G*M/r #Final energy per mass of the particle
  plot(s,l,type="l",col="red",xlab="x",ylab="y",main="Simulated trajectory of a particle in a complex field using the Euler method")
  lines(s,y0+(s-a-h)*tan(theta)+(g*(s-a-h)^2)/(2*(v0*cos(theta))^2))
  legend("bottomleft",legend=c("Calculated","Simulated"),lty=c("solid","solid"),col=c("black","red"))
  return(Eb/Ea)
}
complexEuler(1,50,-1000000,10,pi/4,30)

#Particle in Earth's gravitational field where g varies with r
#Midpoint method
G=6.6743015*10^(-11)
M=5.974*10^24
R=6.38*10^6
complexMidpoint=function(a,b,y0,v0,theta,N){
  r=R+y0
  g=-G*M/r^2
  y=function(x){
    (x-a)*tan(theta)+(g*(x-a)^2)/(2*(v0*cos(theta))^2) #The midpoint method also requires the trajectory equation to evolve y
  }
  yprime=function(x,y){
    y/(x-a)+(g*(x-a))/(2*(v0*cos(theta))^2)
  }
  h=(b-a)/N
  l=c(y0)
  s=seq(a+h,b,by=h)
  Ea=0.5*v0^2-G*M/r
  for (i in 0:N-1){
    l=c(l,l[i]+h*yprime(s[i]+h/2,y(s[i])+0.5*h*yprime(s[i],y(s[i]))))
    r=R+l[i+1]
    g=-G*M/r^2
  }
  v=sqrt((v0*cos(theta))^2+(v0*sin(theta)+g*(b-a)/(v0*cos(theta)))^2)
  Eb=0.5*v^2-G*M/r
  plot(s,l,type="l",col="purple",xlab="x",ylab="y",main="Simulated trajectory of a particle in a complex field using the Midpoint method")
  lines(s,y0+(s-a-h)*tan(theta)+(g*(s-a-h)^2)/(2*(v0*cos(theta))^2))
  legend("bottomleft",legend=c("Calculated","Midpoint method"),lty=c("solid","solid"),col=c("black","purple"))
  return(Eb/Ea)
}
complexMidpoint(1,50,-1000000,10,pi/4,30)

#Particle in Earth's gravitational field where g varies with r
#Modified Euler method
G=6.6743015*10^(-11)
M=5.974*10^24
R=6.38*10^6
complexMod.Euler=function(a,b,y0,v0,theta,N){
  r=R+y0
  g=-G*M/r^2
  y=function(x){
    (x-a)*tan(theta)+(g*(x-a)^2)/(2*(v0*cos(theta))^2)
  }
  yprime=function(x,y){
    y/(x-a)+(g*(x-a))/(2*(v0*cos(theta))^2)
  }
  h=(b-a)/N
  l=c(y0)
  s=seq(a+h,b,by=h)
  Ea=0.5*v0^2-G*M/r
  for (i in 0:N-1){
    l=c(l,l[i]+0.5*h*(yprime(s[i],y(s[i]))+yprime(s[i+1],y(s[i])+h*yprime(s[i],y(s[i])))))
    r=R+l[i+1]
    g=-G*M/r^2
  }
  v=sqrt((v0*cos(theta))^2+(v0*sin(theta)+g*(b-a)/(v0*cos(theta)))^2)
  Eb=0.5*v^2-G*M/r
  plot(s,l,type="l",col="grey",xlab="x",ylab="y",main="Simulated trajectory of a particle in a complex field using the Modified Euler method")
  lines(s,y0+(s-a-h)*tan(theta)+(g*(s-a-h)^2)/(2*(v0*cos(theta))^2))
  legend("bottomleft",legend=c("Calculated","Simulated"),lty=c("solid","solid"),col=c("black","grey"))
  return(Eb/Ea)
}
complexMod.Euler(1,50,-1000000,10,pi/4,30)

#Particle in Earth's gravitational field where g varies with r
#Runge-Kutta method
G=6.6743015*10^(-11)
M=5.974*10^24
R=6.38*10^6
complexRungeKutta=function(a,b,y0,v0,theta,N){
  r=R+y0
  g=-G*M/r^2
  y=function(x){
    (x-a)*tan(theta)+(g*(x-a)^2)/(2*(v0*cos(theta))^2)
  }
  yprime=function(x,y){
    tan(theta)+(g*(x-a))/((v0*cos(theta))^2)
  }
  h=(b-a)/N
  s=seq(a,b,by=h)
  l=c(y0)
  Ea=0.5*v0^2-G*M/r
  for (i in 1:N){ #The number of FOR loops has to be modified for the Runge-Kutta method to work
    K1=h*yprime(s[i],y(s[i]))
    K2=h*yprime(s[i]+h/2,y(s[i])+K1/2)
    K3=h*yprime(s[i]+h/2,y(s[i])+K2/2)
    K4=h*yprime(s[i]+h,y(s[i])+K3)
    l=c(l,y0+y(s[i])+(K1+2*K2+2*K3+K4)/6)
    r=R+l[i+1]
    g=-G*M/r^2
  }
  v=sqrt((v0*cos(theta))^2+(v0*sin(theta)+g*(b-a)/(v0*cos(theta)))^2)
  Eb=0.5*v^2-G*M/r
  plot(s,l,type="l",col="pink",xlab="x",ylab="y",main="Simulated trajectory of a particle in a complex field using the Runge-Kutta method")
  lines(s,y0+(s-a)*tan(theta)+(g*(s-a)^2)/(2*(v0*cos(theta))^2))
  legend("bottomleft",legend=c("Calculated","Runge-Kutta method"),lty=c("solid","solid"),col=c("black","pink"))
  return(Eb/Ea)
}
complexRungeKutta(1,50,-1000000,10,pi/4,30)



#Pair of massive particles interacting in 3D
#System of ODEs using 3D vectors
G=-6.6743015*10^-11
cpt=function(P,N,mi,mj,rix,riy,riz,rjx,rjy,rjz,v0ix,v0iy,v0iz,v0jx,v0jy,v0jz){
  ri=c(rix,riy,riz)
  rj=c(rjx,rjy,rjz)
  v0i=c(v0ix,v0iy,v0iz)
  v0j=c(v0jx,v0jy,v0jz)
  rij=ri-rj
  modrij=sqrt(sum(rij^2))
  xi=c(rix)
  yi=c(riy)
  zi=c(riz)
  xj=c(rjx)
  yj=c(rjy)
  zj=c(rjz)
  for(i in 1:N){
    ri=(G*mj*rij/modrij^3)*((P/N)^2)/2+v0i*(P/N)+ri
    rj=(-G*mi*rij/modrij^3)*((P/N)^2)/2+v0j*(P/N)+rj
    v0i=(G*mj*rij/modrij^3)*(P/N)+v0i
    v0j=(-G*mi*rij/modrij^3)*(P/N)+v0j
    xi=c(xi,ri[1])
    yi=c(yi,ri[2])
    zi=c(zi,ri[3])
    xj=c(xj,rj[1])
    yj=c(yj,rj[2])
    zj=c(zj,rj[3])
    rij=ri-rj
    modrij=sqrt(sum(rij^2))
  }
  plot(xj,yj,type="l",col="blue",xlab="x",ylab="y")
  lines(xi,yi)
  legend("bottomleft",legend=c("Body i","Body j"),lty=c("solid","solid"),col=c("black","blue"))
  plot(xj,zj,type="l",col="blue",xlab="x",ylab="y")
  lines(xi,zi)
  legend("bottomleft",legend=c("Body i","Body j"),lty=c("solid","solid"),col=c("black","blue"))
  plot(yj,zj,type="l",col="blue",xlab="x",ylab="y")
  lines(yi,zi)
  legend("bottomleft",legend=c("Body i","Body j"),lty=c("solid","solid"),col=c("black","blue"))
}
cpt(2419200,3000,5.9722*10^24,7.342*10^22,0,0,0,3.844*10^8,0,0,0,0,0,0,1022,0)
cpt(31557600,3000,1.9885*10^30,5.97219*10^24,0,0,0,1.5021*10^11,0,0,0,0,0,0,29907.13061,0)



#3 massive bodies interacting in 3D
G=-6.6743015*10^-11
cmt=function(P,N,mi,mj,mk,rix,riy,riz,rjx,rjy,rjz,rkx,rky,rkz,v0ix,v0iy,v0iz,v0jx,v0jy,v0jz,v0kx,v0ky,v0kz){
  ri=c(rix,riy,riz)
  rj=c(rjx,rjy,rjz)
  rk=c(rkx,rky,rkz)
  v0i=c(v0ix,v0iy,v0iz)
  v0j=c(v0jx,v0jy,v0jz)
  v0k=c(v0kx,v0ky,v0kz)
  L0i=mi*c(riy*v0iz-riz*v0iy,riz*v0ix-rix*v0iz,rix*v0iy-riy*v0ix)
  L0j=mj*c(rjy*v0jz-rjz*v0jy,rjz*v0jx-rjx*v0jz,rjx*v0jy-rjy*v0jx)
  L0k=mk*c(rky*v0kz-rkz*v0ky,rkz*v0kx-rkx*v0kz,rkx*v0ky-rky*v0kx)
  p0i=mi*v0i
  p0j=mj*v0j
  p0k=mk*v0k
  rij=ri-rj
  rik=ri-rk
  rjk=rj-rk
  modrij=sqrt(sum(rij^2))
  modrik=sqrt(sum(rik^2))
  modrjk=sqrt(sum(rjk^2))
  xi=c(rix)
  yi=c(riy)
  zi=c(riz)
  xj=c(rjx)
  yj=c(rjy)
  zj=c(rjz)
  xk=c(rkx)
  yk=c(rky)
  zk=c(rkz)
  for(i in 1:N){
    ri=((G*mj*rij/modrij^3)+(G*mk*rik/modrik^3))*((P/N)^2)/2+v0i*(P/N)+ri
    rj=((-G*mi*rij/modrij^3)+(G*mk*rjk/modrjk^3))*((P/N)^2)/2+v0j*(P/N)+rj
    rk=((-G*mi*rik/modrik^3)+(-G*mj*rjk/modrjk^3))*((P/N)^2)/2+v0k*(P/N)+rk
    v0i=((G*mj*rij/modrij^3)+(G*mk*rik/modrik^3))*(P/N)+v0i
    v0j=((-G*mi*rij/modrij^3)+(G*mk*rjk/modrjk^3))*(P/N)+v0j
    v0k=((-G*mi*rik/modrik^3)+(-G*mj*rjk/modrjk^3))*(P/N)+v0k
    xi=c(xi,ri[1])
    yi=c(yi,ri[2])
    zi=c(zi,ri[3])
    xj=c(xj,rj[1])
    yj=c(yj,rj[2])
    zj=c(zj,rj[3])
    xk=c(xk,rk[1])
    yk=c(yk,rk[2])
    zk=c(zk,rk[3])
    rij=ri-rj
    rik=ri-rk
    rjk=rj-rk
    modrij=sqrt(sum(rij^2))
    modrik=sqrt(sum(rik^2))
    modrjk=sqrt(sum(rjk^2))
  }
  Li=mi*c(ri[2]*v0i[3]-ri[3]*v0i[2],ri[3]*v0i[1]-ri[1]*v0i[3],ri[1]*v0i[2]-ri[2]*v0i[1])
  Lj=mj*c(rj[2]*v0j[3]-rj[3]*v0j[2],rj[3]*v0j[1]-rj[1]*v0j[3],rj[1]*v0j[2]-rj[2]*v0j[1])
  Lk=mk*c(rk[2]*v0k[3]-rk[3]*v0k[2],rk[3]*v0k[1]-rk[1]*v0k[3],rk[1]*v0k[2]-rk[2]*v0k[1])
  pi=mi*v0i
  pj=mj*v0j
  pk=mk*v0k
  plot(xk,yk,type="l",col="red",xlab="x",ylab="y")
  lines(xj,yj,type="l",col="blue")
  lines(xi,yi,type="l")
  legend("bottomleft",legend=c("Body i","Body j","Body k"),lty=c("solid","solid","solid"),col=c("black","blue","red"))
  plot(xk,zk,type="l",col="red",xlab="x",ylab="z")
  lines(xj,zj,type="l",col="blue")
  lines(xi,zi,type="l")
  legend("bottomleft",legend=c("Body i","Body j","Body k"),lty=c("solid","solid","solid"),col=c("black","blue","red"))
  plot(yk,zk,type="l",col="red",xlab="y",ylab="z")
  lines(yj,zj,type="l",col="blue")
  lines(yi,zi,type="l")
  legend("bottomleft",legend=c("Body i","Body j","Body k"),lty=c("solid","solid","solid"),col=c("black","blue","red"))
  return(c((Li+Lj+Lk)/(L0j+L0i+L0k),(pi+pj+pk)/(p0i+p0j+p0k)))
}
cmt(59350752,3000,1.9885*10^30,5.97219*10^24,6.39*10^23,0,0,0,1.495978707*10^11,0,0,0,227.9*10^9,0,0,0,0,0,29951.68,0,-24130.772,0,0)
