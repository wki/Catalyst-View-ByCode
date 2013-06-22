template {
    div main {
        c->req->params->{input} || 'static: ö'
    };
};
