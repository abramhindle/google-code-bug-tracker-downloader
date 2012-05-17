for project in `cat targets.txt`
do
    echo $project
    perl google-code.pl -project $project
done
