ruby $OUTPUT/script/create_analytics_report.rb -i $ID -a $AUTH  -s $STARTDATE -e $ENDDATE -o $OUTPUT
cat $OUTPUT/output_${STARTDATE}_${ENDDATE}.csv