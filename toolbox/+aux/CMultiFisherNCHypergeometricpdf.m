
function Wpdf = CMultiFisherNCHypergeometricpdf(x,m,omega, accuracy)
%CMultiFisherNCHypergeometricpdf returns multivariate Fisher' non-central hypergeometric probability density function
% n = number of balls taken
%  m = number of balls for each color
%  total number of balls in the urn = sum(m)
% x = number of successes for each ball
% omega = vector of odds

if nargin<4
    accuracy =1e-10;
end

m=m(:);
omega=omega(:);


colors=length(m);
n=sum(x);
N=sum(m);

if (colors < 3)
    if (colors <= 0)
        Wpdf=1;
        return
    end

    if (colors == 1)
        Wpdf=x(1) == m(1);
        return
    end

    if colors == 2

        if (omega(2) == 0.)
            Wpdf=x(1) == m(1);
            return
        end

        odds=omega(1)/omega(2);
        %  x,n,m,N,omega
        Wpdf= aux.FisherNCHypergeometricpdf(x(1),n,m(1),N,odds,accuracy);
        return
    end
end


j=0;
em=0;

central = 1;
for i  = 0:1:colors-1
    if x(i+1) > m(i+1) || x(i+1) < 0 || x(i+1) < n - N + m(i+1)
        Wpdf=0;
        return
    end

    if (x(i+1) > 0)
        j=j+1;
    end

    if (omega(i+1) == 0. && x(i+1)~=0)
        Wpdf=0;
        return
    end

    if (x(i+1) == m(i+1) || omega(i+1) == 0.)
        em=em+1;
    end

    if i > 1 && omega(i+1) ~= omega(i)
        central = 0;
    end

end

if (n == 0 || em == colors)
    Wpdf=1;
    return
end

if central ==1

    %// All omega's are equal.
    % // This is multivariate central hypergeometric distribution
    p = 1;
    sx=n; sm=N;
    for i = 1:colors
        % // Use univariate hypergeometric (usedcolors-1) times
        p = p* hygepdf(x(i), sm, m(i),sx);
        sx = sx- x(i);
        sm = sm -m(i);
    end
    Wpdf=p;
    return
end

mFac=computemFac(m);

[rsum,scale]=SumOfAll(m,omega,n,mFac,accuracy);
Wpdf=exp(lng(x,m,omega,mFac,scale))*rsum;
end


function z=lng(x,m,w,mFac,scale)
colors=length(m);
y=0;
% // natural log of proportional function g(x)
for i = 1:colors
    y = y+x(i)*log(w(i)) - logfactorial(x(i)) - logfactorial(m(i)-x(i));

end
z= mFac + y - scale;
end



function mFac=computemFac(m)
colors=length(m);
mFac=0;
for i = 1:colors
    mFac = mFac + logfactorial(m(i));
end
end


function [rsum,scale]=SumOfAll(m,omega,n,mFac, accuracy)
% // this function does the very time consuming job of calculating the sum
% // of the proportional function g(x) over all possible combinations of
% // the x[i] values with probability > accuracy. These combinations are
% // generated by the recursive function loop().
% // The mean and variance are generated as by-products.

%   int32_t msum;                         // sum of m[i]

%// get approximate mean
sx=meand(m,omega,n);
% // round mean to integers
msum=0;
colors=length(m);
xm=zeros(colors,1);
for i=1:colors
    xm(i)=round(sx(i));

    msum = msum+xm(i); 
end
%// adjust truncated x values to make the sum = n
msum = msum-n;

i=1;
while msum<0
    if xm(i) < m(i)
        xm(i)=xm(i)+1;
        msum=msum+1;
    end
    i=i+1;
end

i=1;
while msum>0
    if (xm(i) > 0)
        xm(i)=xm(i)-1;
        msum=msum-1;
    end
    i=i+1;
end

%// adjust scale factor to g(mean) to avoid overflow
scale=0;
scale = lng(xm,m,omega,mFac,scale);
remaining=zeros(colors,1);

% // initialize for recursive loops
sn = 0;
msum = 0;
for i = colors:-1:1
    remaining(i) = msum;
    msum = msum+m(i);
end
xi=zeros(colors,1);

% sxx=xi;
% sx=xi;

% // recursive loops to calculate sums of g(x) over all x combinations
[sumd,~,~]=loop(n, 1,colors,remaining,m,xm, omega,mFac,scale,accuracy,xi,sn);
rsum = 1./ sumd ;

% % // calculate mean and variance
% for i = 1:colors
%     sxx(i) = sxx(i)*rsum - sx(i)*sx(i)*rsum*rsum;
%     sx(i) = sx(i)*rsum;
% end
end


function [sumd,xi,sn]=loop(n, c, colors,remaining,m,xm, omega,mFac,scale, accuracy,xi,sn)
% // recursive function to loop through all combinations of x-values.
% // used by SumOfAll

sumd=0;
% sx=zeros(colors,1);
% sxx=sx;
if (c < colors)
    % // not the last color
    % // calculate min and max of x[c] for given x[0]..x[c-1]
    xmin = n - remaining(c);

    if (xmin < 0)
        xmin = 0;
    end

    xmax = m(c);
    if (xmax > n)
        xmax = n;
    end

    x0 = xm(c);
    if (x0 < xmin)
        x0 = xmin;
    end
    if (x0 > xmax)
        x0 = xmax;
    end

    % // loop for all x[c] from mean and up
    s2 = 0.;
    for x =x0:xmax
        xi(c) = x;
        [s1,xi,sn]= loop(n-x, c+1,    colors,remaining,m,xm, omega,mFac,scale,accuracy,xi,sn); % // recursive loop for remaining colors
        sumd = sumd+ s1;
        if (s1 < accuracy && s1 < s2)
            break % // stop when values become negligible
        end

        s2 = s1;
    end
    % // loop for all x[c] from mean and down
    for x = x0-1:-1: xmin
        xi(c) = x;
        [s1,xi,sn] = loop(n-x, c+1,    colors,remaining,m,xm, omega,mFac,scale,accuracy,xi,sn);  %  // recursive loop for remaining colors
        sumd = sumd+s1;
        if (s1 < accuracy && s1 < s2)
            break % // stop when values become negligible
        end
        s2 = s1;
    end

else
    % // last color
    xi(c) = n;
    % // sums and squaresums
    s1 = exp(lng(xi,m,omega,mFac,scale));               % // proportional function g(x)
    % for i = 1:colors  %    // update sums
    %     sx(i)  = sx(i) +s1 * xi(i);
    %     sxx(i) = sxx(i) + s1 * xi(i) * xi(i);
    % end
    sn=sn+1;
    sumd = sumd+s1;
end
end


function mu=meand(m,odds,n)
% // calculates approximate mean of multivariate Fisher's noncentral
% // hypergeometric distribution. Result is returned in mu[0..colors-1].
% // The calculation is reasonably fast.
% // Note: The version in BiasedUrn package deals with unused colors

N=sum(m); % TOCHECK
colors=length(m);
mu=zeros(colors,1);

if (colors < 3)
    % // simple cases
    if (colors == 1)
        mu(1) = n;
    end

    if (colors == 2)
        mu(1) = CFishersNCHypergeometric(n,m(1),m(1)+m(2),odds(1)/odds(2)).mean;

        mu(2) = n - mu(0);
        return
    end
end

if (n == N)
    % // Taking all balls
    mu=m;
    return
end

% // initial guess for r
W=0;
for i=1:colors
    W = W+ m(i) * odds(i);
    r = n * N / ((N-n)*W);
end

% // iteration loop to find r
r1=Inf; iter=0;
while abs(r-r1) > 1E-5
    r1 = r;
    q=0;
    for i=1:colors
        q = q+ m(i) * r * odds(i) / (r * odds(i) + 1.);
    end
    r = r* n * (N-q) / (q * (N-n));
    iter=iter+1;
    if (iter > 100)
        error("convergence problem in function CMultiFishersNCHypergeometric::mean");
    end
end

% // store result
for i=1:colors
    mu(i) = m(i) * r * odds(i) / (r * odds(i) + 1.);
end
end