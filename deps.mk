# ./bin/build-boto-services.pl.in
./bin/build-boto-services.pl: \
    ./lib/Amazon/API/Botocore.pm

# ./lib/Amazon/API.pm.in
./lib/Amazon/API.pm: \
    ./lib/Amazon/API/Botocore.pm \
    ./lib/Amazon/API/Botocore/Shape.pm \
    ./lib/Amazon/API/Botocore/Shape/Serializer.pm \
    ./lib/Amazon/API/Botocore/Shape/Utils.pm \
    ./lib/Amazon/API/Constants.pm \
    ./lib/Amazon/API/Error.pm \
    ./lib/Amazon/API/HTTP/UserAgent.pm \
    ./lib/Amazon/API/NullLogger.pm \
    ./lib/Amazon/API/Signature4.pm

# ./lib/Amazon/API/Botocore.pm.in
./lib/Amazon/API/Botocore.pm: \
    ./lib/Amazon/API/Botocore/Pod.pm \
    ./lib/Amazon/API/Botocore/Shape/Utils.pm \
    ./lib/Amazon/API/BuildInfo.pm \
    ./lib/Amazon/API/Constants.pm \
    ./lib/Amazon/API/Pod/Parser.pm \
    ./lib/Amazon/API/Template.pm

# ./lib/Amazon/API/Botocore/Services.pm.in
./lib/Amazon/API/Botocore/Services.pm: \
    ./lib/Amazon/API/Botocore.pm

# ./lib/Amazon/API/Botocore/Shape.pm.in
./lib/Amazon/API/Botocore/Shape.pm: \
    ./lib/Amazon/API/Botocore/Shape/Utils.pm \
    ./lib/Amazon/API/Constants.pm \
    ./lib/Amazon/API/NullLogger.pm

# ./lib/Amazon/API/Botocore/Shape/Serializer.pm.in
./lib/Amazon/API/Botocore/Shape/Serializer.pm: \
    ./lib/Amazon/API/Botocore/Shape.pm \
    ./lib/Amazon/API/Botocore/Shape/Utils.pm \
    ./lib/Amazon/API/Constants.pm

# ./lib/Amazon/API/Botocore/Shape/Utils.pm.in
./lib/Amazon/API/Botocore/Shape/Utils.pm: \
    ./lib/Amazon/API/BuildInfo.pm \
    ./lib/Amazon/API/Constants.pm

# ./lib/Amazon/API/HTTP/UserAgent.pm.in
./lib/Amazon/API/HTTP/UserAgent.pm: \
    ./lib/Amazon/API/HTTP/Response.pm

# ./lib/Amazon/API/ModuleNames.pm.in
./lib/Amazon/API/ModuleNames.pm: \
    ./lib/Amazon/API/Botocore.pm

# ./lib/Amazon/API/Pod/Parser.pm.in
./lib/Amazon/API/Pod/Parser.pm: \
    ./lib/Amazon/API/Pod/Simple/Text.pm

# ./lib/Amazon/API/Provenance.pm.in
./lib/Amazon/API/Provenance.pm: \
    ./lib/Amazon/API/Botocore.pm \
    ./lib/Amazon/API/Provenance/Role/KMS.pm \
    ./lib/Amazon/API/Provenance/Role/Records.pm \
    ./lib/Amazon/API/Provenance/Role/SSM.pm

# ./lib/Amazon/API/Provenance/Role/Records.pm.in
./lib/Amazon/API/Provenance/Role/Records.pm: \
    ./lib/Amazon/API/BuildInfo.pm

# ./lib/Amazon/API/Template.pm.in
./lib/Amazon/API/Template.pm: \
    ./lib/Amazon/API/Constants.pm

