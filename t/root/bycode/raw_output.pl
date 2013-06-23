template {
    div main {
        print RAW c->req->params->{input} || 'static: ö';
    };
};
