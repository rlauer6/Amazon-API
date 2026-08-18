# ./lib/Amazon/API.pm.in
./lib/Amazon/API.pm: \
    ./lib/Amazon/API/Botocore/Shape.pm \
    ./lib/Amazon/API/Botocore/Shape/Serializer.pm \
    ./lib/Amazon/API/Botocore/Shape/Utils.pm \
    ./lib/Amazon/API/Constants.pm \
    ./lib/Amazon/API/Error.pm \
    ./lib/Amazon/API/HTTP/UserAgent.pm \
    ./lib/Amazon/API/NullLogger.pm \
    ./lib/Amazon/API/Role/Botocore.pm \
    ./lib/Amazon/API/Signature4.pm

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
    ./lib/Amazon/API/Constants.pm \
    ./lib/Amazon/API/Role/Botocore.pm

# ./lib/Amazon/API/CLI.pm.in
./lib/Amazon/API/CLI.pm: \
    ./lib/Amazon/API/BuildInfo.pm \
    ./lib/Amazon/API/Role/Botocore.pm \
    ./lib/Amazon/API/Role/ModuleNames.pm \
    ./lib/Amazon/API/Role/Services.pm

# ./lib/Amazon/API/HTTP/UserAgent.pm.in
./lib/Amazon/API/HTTP/UserAgent.pm: \
    ./lib/Amazon/API/HTTP/Response.pm

# ./lib/Amazon/API/Provenance.pm.in
./lib/Amazon/API/Provenance.pm: \
    ./lib/Amazon/API/Provenance/Role/KMS.pm \
    ./lib/Amazon/API/Provenance/Role/Records.pm \
    ./lib/Amazon/API/Provenance/Role/SSM.pm \
    ./lib/Amazon/API/Role/Botocore.pm

# ./lib/Amazon/API/Provenance/Role/Records.pm.in
./lib/Amazon/API/Provenance/Role/Records.pm: \
    ./lib/Amazon/API/BuildInfo.pm

# ./lib/Amazon/API/Role/Botocore.pm.in
./lib/Amazon/API/Role/Botocore.pm: \
    ./lib/Amazon/API/Constants.pm \
    ./lib/Amazon/API/Template.pm

# ./lib/Amazon/API/Role/Services.pm.in
./lib/Amazon/API/Role/Services.pm: \
    ./lib/Amazon/API/Constants.pm

# ./lib/Amazon/API/Template.pm.in
./lib/Amazon/API/Template.pm: \
    ./lib/Amazon/API/Constants.pm

