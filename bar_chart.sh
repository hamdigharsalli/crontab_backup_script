#!/bin/sh

#
# Draws a bar chart
#
# Usage: bar_chart "label percentage"
#
# (The arguments are together in one unit because of the way
# the function is called from within bash with "while read".)
#

function bar_chart
{
    label=`echo $1 | cut -d ' ' -f 1`
    percentage=`echo $1 | cut -d ' ' -f 2`

    bar_chart_width=50
    scale_factor=$(expr 100 / $bar_chart_width)

    if [[ $percentage -lt 0 ]]; then
        echo "Usage: $0 0 -le percentage -le 100"
        exit 1
    fi

    length_of_bar=$(expr $percentage / $scale_factor)
    remaining_length=$(expr 100 / $scale_factor - $length_of_bar)

    /bin/echo -n "$label`printf '\t%2d%%\t' $percentage`"

    for i in `seq 0 $length_of_bar`; do
        /bin/echo -n "*"
    done

    for i in `seq 0 $remaining_length`; do
        /bin/echo -n "-"
    done

    echo "|"
}

df_command="/bin/df -PHl"

function show_disk_space_graphically
{
    $df_command | tr -s ' ' | cut -d ' ' -f 1,5 \
        | cut -d '%' -f 1 | sed '1d' \
        | while read -r line; do bar_chart "$line"; done
}

show_disk_space_graphically

