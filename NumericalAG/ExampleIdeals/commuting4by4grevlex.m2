R = ZZ/32003[a..F]
I = ideal(
   -j*o+i*p-v*A+u*B-x*C+w*D,
   b*o-d*o-a*p+c*p-l*A+k*B-n*C+m*D,
   p*q-o*r+b*A-f*A-a*B+e*B-z*C+y*D,
   p*s-o*t+b*C-h*C-a*D+g*D+B*E-A*F,
   -b*i+d*i+a*j-c*j+r*u-q*v+t*w-s*x,
   j*o-i*p-l*q+k*r-n*s+m*t,
   d*q-f*q-c*r+e*r+t*y-s*z+j*A-i*B,
   d*s-h*s-c*t+g*t+j*C-i*D+r*E-q*F,
   -j*k+i*l-b*u+f*u+a*v-e*v-x*E+w*F,
   -d*k+f*k+c*l-e*l-p*u+o*v-n*E+m*F,
   l*q-k*r+v*A-u*B-z*E+y*F,
   l*s-k*t+v*C-u*D+f*E-h*E-e*F+g*F,
   -j*m+i*n-b*w+h*w+a*x-g*x-v*y+u*z,
   -d*m+h*m+c*n-g*n-p*w+o*x-l*y+k*z,
   n*q-m*r-f*y+h*y+e*z-g*z+x*A-w*B,
   n*s-m*t+x*C-w*D+z*E-y*F);
time gens gb I;
I = ideal I_*;
time gens gb(I, Algorithm=>Homogeneous2, Strategy=>LongPolynomial);

