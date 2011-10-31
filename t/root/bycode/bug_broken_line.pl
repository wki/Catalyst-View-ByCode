template {
# did work in perl 5.14:
 
#            a._ajax.table_action_button
#             .detail_button(href => c->uri_for_action('approval/concept', $concept->concept_id, $proofkind),
#                            title => 'Details', 
#                            data_target => '-new', 
#                            data_title => 'Details') {
#                span.hide {'Details'};
#            };


# did not work in perl 5.14:

#            a._ajax
#             .table_action_button
#             .detail_button(href => c->uri_for_action('approval/concept', $concept->concept_id, $proofkind),
#                            title => 'Details', 
#                            data_target => '-new', 
#                            data_title => 'Details') {
#                span.hide {'Details'};
#            };


# simplified code that threw the error: (indentation also important!)

           a._ajax
            .table_action_button
            .detail_button(href => 'approval/concept',
                           title => 'Details', 
                           data_target => '-new', 
                           data_title => 'Details') {
               span.hide {'Details'};
           } ; # x
};
