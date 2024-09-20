#!/bin/bash

# directory and files names
readfile=particles_example
directory=distribution
savefile=distribution
savefile2=linearization

##### Parameters #####
lt=7;    # line type (color)
pt=7;    # point type 
lc=-1;   # point color
ps=0.75; # point size

# initialize values
x0=0; x1=0; y0=0; y1=0

# RRB parameter, used in linear interpolation calculations
yi=0.632

# remove blank lines and sort file by crescent order using second column
sed '/^$/d' $readfile | sort --key 2 --numeric-sort > temp &&

# Read file line per line and gets values for interpolation
while IFS= read -r line; 
do
    [[ "$line" =~ ^#.*$ ]] && continue

    x=$(echo $line | awk '{print $1}');# particle diameter     -> column 1
    y=$(echo $line | awk '{print $2}');# y (passing cumulated) -> column 2

    isGreater=$(awk "BEGIN {print ($y>$yi?1:0);exit}")

    if [[ "$isGreater" -eq 0 ]]; then
        x0=$x; y0=$y
    fi

    if [[ "$isGreater" -eq 1 ]]; then
        x1=$x; y1=$y
        break
    fi
done < temp

# Linear interpolation calculations
dLine=$(awk "BEGIN {print ($y0==$y1 ? ($x0+$x1)/2. : ($x1-$x0)/($y1-$y0)*($yi-$y0) + $x0);exit}")

mkdir -p $directory
cd $directory
rm -f fit.log

gnuplot -persist <<-EOFMarker
    set terminal cairolatex header '\newcommand{\hl}[2][1]{\setlength{\fboxsep}{#1pt}\colorbox{white}{#2}}'
    data = "../temp"
    set grid front
    set key bottom right
    set decimalsign ','
    set key samplen 4
    set key spacing 1.25
    set key font ",10"
    set xlabel 'Particle diameter \$\\left({\mu}m\\right)\$'
    set ylabel 'Cumulative content \$\\left(y\\right)\$' offset -1.4,0

    g(y) = (log10(log10(1./(1.-y))))
    rrb(x) = (1-exp(-(x/${dLine})**n)); # Rosin-Rammler-Bennett distribution function

    mean(x)= m
    fit mean(x) data using (log10(\$1)):(g(\$2)) via m
    SST = FIT_WSSR/(FIT_NDF+1)

    set print "-"
    print '**********************************************************************'

    f(x) = n*x + b

    fit f(x) data using (log10(\$1)):(g(\$2)) via n,b
    SSE = FIT_WSSR/(FIT_NDF)

    set print "-"
    print 'd_line          = ', sprintf('%.4f', ${dLine})
    set print "fit.log" append
    print 'd_line          = ', sprintf('%.4f', ${dLine})

    SSR = SST-SSE
    R2  = SSR/SST

    set print "-"
    print 'R^2             = ', sprintf('%.4f', R2)
    set print "fit.log" append
    print 'R^2             = ', sprintf('%.4f', R2)

    frac_dLine=100.*(${dLine} - floor(${dLine}))
    frac_n=100.*abs(n - (n<0?ceil(n):floor(n)))
    frac_b=100.*(b<0?(abs(b-ceil(b))):(b-floor(b)))
    frac_r2=1000.*R2

#   distributive content plot
    set out '${savefile}.tex'
    plot data using 1:2 with points t 'Experimental data' lt $pt lc $lc ps $ps, \
         rrb(x) title 'Rosin-Rammler-Bennett equation' lt $lt
    set out

    unset border
    set grid front
    set zeroaxis lt -1
    set lmargin 5
    set bmargin 3
    set xtics axis offset 0,0.2
    set ytics axis offset 0.2,0
    set xtics add ("" 0)
    set ytics add ("" 0)

    set xlabel '\$log_{10}\\left(d\\right)\$' offset 0,-1.25
    set y2label '\$log_{10}\\left(log_{10}\\left(\\frac{1}{\\left(1-y\\right)}\\right)\\right)\$' offset 0.5,0

    set format x '%2.1f'
    set format y '%2.1f'
    set key top left

#   linearization plot
    set out '${savefile2}.tex'
    stats data using (log10(\$1)):(g(\$2)) nooutput
    dx = STATS_pos_max_y - STATS_pos_min_y
    dy = STATS_max_y - STATS_min_y
    x1 = STATS_pos_max_y - 0.25*dx
    y1 = STATS_min_y + 0.20*dy
    y2 = STATS_min_y + 0.05*dy
    set label 1 sprintf("\\\hl[4]{\$y = %2d{,}%02d x %s %2d{,}%02d\$}", (n<0?ceil(n):floor(n)), ((frac_n - floor(frac_n) > 0.5)?frac_n+1:frac_n), (b<0?'-':'+'), abs(b<0?ceil(b):floor(b)), ((frac_b - floor(frac_b) > 0.5)?frac_b+1:frac_b)) at x1,y1 front
    set label 2 sprintf("\\\hl[4]{\$R^2 = 0{,}%03d\$}", frac_r2) at x1,y2 front
    plot data using (log10(\$1)):(g(\$2)) with points t "\$y\$" lt $pt lc $lc ps $ps, \
         f(x) title "Linear \$\\\left(y\\\right)\$" lt $lt
    set out

EOFMarker

rm ../temp

#### Correct \includegraphics{} pathfile in .tex files

sed -i 's/includegraphics{/includegraphics{'${directory}'\//g' ${savefile}.tex
sed -i 's/includegraphics{/includegraphics{'${directory}'\//g' ${savefile2}.tex

#### Create article example using .tex graphics
cd ..
mkdir -p build
pdflatex -shell-escape -halt-on-error -output-directory=build article.tex
