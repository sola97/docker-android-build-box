# Installed Software Versions
ARG ANDROID_SDK_TOOLS_TAGGED="latest"
ARG ANDROID_SDK_TOOLS_VERSION="11076708"

ARG ANDROID_SDKS="last8"
ARG NDK_TAGGED="latest"
ARG NDK_VERSION="26.2.11394342"

ARG JENV_TAGGED="latest"
ARG JENV_RELEASE="0.5.6"

#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
#                PRELIMINARY STAGES
#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
FROM ubuntu:22.04 as ubuntu
ARG ANDROID_SDK_TOOLS_VERSION
ARG NDK_VERSION
ARG JENV_RELEASE

ARG DIRWORK="/tmp"
ARG FINAL_DIRWORK="/project"

ARG INSTALLED_TEMP="${DIRWORK}/.temp_version"
ARG INSTALLED_VERSIONS="/root/installed-versions.txt"

ARG SDK_PACKAGES_LIST="${DIRWORK}/packages.txt"

ENV ANDROID_HOME="/opt/android-sdk" \
    ANDROID_SDK_HOME="/opt/android-sdk" \
    ANDROID_NDK="/opt/android-sdk/ndk/latest" \
    ANDROID_NDK_ROOT="/opt/android-sdk/ndk/latest" \
    JENV_ROOT="/opt/jenv"

ENV ANDROID_SDK_MANAGER=${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager

ENV TZ=America/Los_Angeles

# Set locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"

ENV ANDROID_SDK_HOME="$ANDROID_HOME"
ENV ANDROID_NDK_HOME="$ANDROID_NDK"

ENV PATH="${JENV_ROOT}/shims:${JENV_ROOT}/bin:$JAVA_HOME/bin:$PATH:$ANDROID_SDK_HOME/cmdline-tools/latest/bin:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$ANDROID_NDK"

#----------~~~~~~~~~~*****
# build stage: base
#----------~~~~~~~~~~*****
FROM ubuntu as pre-base
ARG TERM=dumb \
    DEBIAN_FRONTEND=noninteractive

WORKDIR ${DIRWORK}

RUN uname -a && uname -m

RUN JDK_PLATFORM=$(if [ "$(uname -m)" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    echo export JDK_PLATFORM=$JDK_PLATFORM >> /etc/jdk.env && \
    echo export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-$JDK_PLATFORM/" >> /etc/jdk.env && \
    echo . /etc/jdk.env >> /etc/bash.bashrc && \
    echo . /etc/jdk.env >> /etc/profile

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get clean && \
    apt-get update -qq && \
    apt-get install -qq -y apt-utils locales && \
    locale-gen $LANG

# Installing packages
RUN apt-get update -qq > /dev/null && \
    apt-get install -qq --no-install-recommends \
        autoconf \
        build-essential \
        cmake \
        ninja-build \
        curl \
        file \
        git \
        gpg-agent \
        less \
        libc6-dev \
        libgmp-dev \
        libmpc-dev \
        libmpfr-dev \
        libxslt-dev \
        libxml2-dev \
        m4 \
        ncurses-dev \
        ocaml \
        openjdk-8-jdk \
        openjdk-11-jdk \
        openjdk-17-jdk \
        openssh-client \
        pkg-config \
        software-properties-common \
        tzdata \
        unzip \
        wget \
        zip \
        zlib1g-dev > /dev/null && \
    git lfs install > /dev/null && \
    . /etc/jdk.env && \
    java -version && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get -y clean && apt-get -y autoremove && rm -rf /var/lib/apt/lists/* && \
    rm -rf ${DIRWORK}/* /var/tmp/*

# preliminary base-base stage
# Install Android SDK CLI
FROM pre-base as base-base
RUN echo '# Installed Versions of Specified Software' >> ${INSTALLED_VERSIONS}

FROM base-base as base-tagged
RUN echo "sdk tools ${ANDROID_SDK_TOOLS_VERSION}" && \
    wget --quiet --output-document=sdk-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_TOOLS_VERSION}_latest.zip" && \
    echo "ANDROID_SDK_TOOLS_VERSION=${ANDROID_SDK_TOOLS_VERSION}" >> ${INSTALLED_VERSIONS}

FROM base-base as base-latest
RUN TEMP=$(curl -S https://developer.android.com/studio/index.html) && \
    ANDROID_SDK_TOOLS_VERSION=$(echo "$TEMP" | grep commandlinetools-linux | tail -n 1 | cut -d \- -f 3 | tr -d _latest.zip\</em\>\<\/p\>) && \
    echo "sdk tools $ANDROID_SDK_TOOLS_VERSION" && \
    wget --quiet --output-document=sdk-tools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-"$ANDROID_SDK_TOOLS_VERSION"_latest.zip" && \
    echo "ANDROID_SDK_TOOLS_VERSION=$ANDROID_SDK_TOOLS_VERSION" >> ${INSTALLED_VERSIONS}

FROM base-${ANDROID_SDK_TOOLS_TAGGED} as base
RUN mkdir --parents "$ANDROID_HOME" && \
    unzip -q sdk-tools.zip -d "$ANDROID_HOME" && \
    cd "$ANDROID_HOME" && \
    mv cmdline-tools latest && \
    mkdir cmdline-tools && \
    mv latest cmdline-tools && \
    rm --force ${DIRWORK}/sdk-tools.zip

# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/

#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
#                INTERMEDIARY STAGES
#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
# jenv
# Add jenv to control which version of java to use, default to 17.
FROM base as jenv-base
RUN echo '#!/usr/bin/env bash' >> ~/.bash_profile && \
    echo 'eval "$(jenv init -)"' >> ~/.bash_profile

FROM jenv-base as jenv-tagged
RUN git clone --depth 1 --branch ${JENV_RELEASE} https://github.com/jenv/jenv.git ${JENV_ROOT} && \
    echo "JENV_RELEASE=${JENV_RELEASE}" >> ${INSTALLED_TEMP}

FROM jenv-base as jenv-latest
RUN git clone  https://github.com/jenv/jenv.git ${JENV_ROOT} && \
    cd ${JENV_ROOT} && echo "JENV_RELEASE=$(git describe --tags HEAD)" >> ${INSTALLED_TEMP}

FROM jenv-${JENV_TAGGED} as jenv-final
RUN . ~/.bash_profile && \
    . /etc/jdk.env && \
    java -version && \
    jenv add /usr/lib/jvm/java-8-openjdk-$JDK_PLATFORM && \
    jenv add /usr/lib/jvm/java-11-openjdk-$JDK_PLATFORM && \
    jenv add /usr/lib/jvm/java-17-openjdk-$JDK_PLATFORM && \
    jenv versions && \
    jenv global 17.0 && \
    java -version

#----------~~~~~~~~~~*****
# build stage: ndk-final
#----------~~~~~~~~~~*****
# NDK (side-by-side)
FROM pre-minimal as ndk-base
WORKDIR ${DIRWORK}
RUN echo "NDK"

FROM ndk-base as ndk-tagged
RUN echo "Installing ${NDK_VERSION}" && \
    . /etc/jdk.env && \
    yes | $ANDROID_SDK_MANAGER ${DEBUG:+--verbose} "ndk;${NDK_VERSION}" > /dev/null && \
    ln -sv $ANDROID_HOME/ndk/${NDK_VERSION} ${ANDROID_NDK}

FROM ndk-base as ndk-latest
RUN NDK=$(grep 'ndk;' ${SDK_PACKAGES_LIST} | sort | tail -n1 | awk '{print $1}') && \
    NDK_VERSION=$(echo $NDK | awk -F\; '{print $2}') && \
    echo "Installing $NDK" && \
    . /etc/jdk.env && \
    yes | $ANDROID_SDK_MANAGER ${DEBUG:+--verbose} "$NDK" > /dev/null && \
    ln -sv $ANDROID_HOME/ndk/$NDK_VERSION ${ANDROID_NDK}

FROM ndk-${NDK_TAGGED} as ndk-final
RUN echo "NDK finished"

#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
#                FINAL BUILD TARGETS
#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
# intended as a functional bare-bones installation
FROM pre-minimal as minimal
COPY --from=jenv-final ${JENV_ROOT} ${JENV_ROOT}
COPY --from=jenv-final ${INSTALLED_TEMP} ${DIRWORK}/.jenv_version
COPY --from=jenv-final /root/.bash_profile /root/.bash_profile

RUN chmod 775 -R $ANDROID_HOME && \
    git config --global --add safe.directory ${JENV_ROOT} && \
    cat ${DIRWORK}/.jenv_version >> ${INSTALLED_VERSIONS} && \
    rm -rf ${DIRWORK}/* && \
    echo "Android SDKs, Build tools, etc Installed: " >> ${INSTALLED_VERSIONS} && \
    . /etc/jdk.env && \
    ${ANDROID_SDK_MANAGER} --list_installed | tail --lines=+2 >> ${INSTALLED_VERSIONS}

WORKDIR ${FINAL_DIRWORK}

#----------~~~~~~~~~~*****
# build target: complete
#----------~~~~~~~~~~*****
FROM minimal as complete
COPY --from=ndk-final --chmod=775 ${ANDROID_NDK_ROOT}/../ ${ANDROID_NDK_ROOT}/../
COPY --from=jenv-final ${JENV_ROOT} ${JENV_ROOT}
COPY --from=jenv-final /root/.bash_profile /root/.bash_profile

COPY README.md /README.md

RUN chmod 775 $ANDROID_HOME $ANDROID_NDK_ROOT/../ && \
    git config --global --add safe.directory ${JENV_ROOT} && \
    cat ${DIRWORK}/.*_version >> ${INSTALLED_VERSIONS} && \
    rm -rf ${DIRWORK}/* && \
    echo "Android SDKs, Build tools, etc Installed: " >> ${INSTALLED_VERSIONS} && \
    . /etc/jdk.env && \
    ${ANDROID_SDK_MANAGER} --list_installed | tail --lines=+2 >> ${INSTALLED_VERSIONS} && \
    ls -l $ANDROID_HOME && \
    ls -l $ANDROID_HOME/ndk && \
    ls -l $ANDROID_HOME/ndk/* && \
    du -sh $ANDROID_HOME

WORKDIR ${FINAL_DIRWORK}

# labels, see http://label-schema.org/
LABEL maintainer="Ming Chen"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="mingc/android-build-box"
LABEL org.label-schema.version="${DOCKER_TAG}"
LABEL org.label-schema.usage="/README.md"
LABEL org.label-schema.docker.cmd="docker run --rm -v `pwd`:${FINAL_DIRWORK} mingc/android-build-box bash -c './gradlew build'"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.vcs-ref="${SOURCE_COMMIT}@${SOURCE_BRANCH}"
#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
#                PRELIMINARY STAGES
#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
# All following stages should have their root as either these two stages,
# ubuntu and base.

#----------~~~~~~~~~~*****
# build stage: ubuntu
#----------~~~~~~~~~~*****
FROM ubuntu:22.04 as ubuntu
# Ensure ARGs are in this build context
ARG ANDROID_SDK_TOOLS_VERSION
ARG NDK_VERSION
ARG JENV_RELEASE

ARG DIRWORK="/tmp"
ARG FINAL_DIRWORK="/project"

ARG INSTALLED_TEMP="${DIRWORK}/.temp_version"
ARG INSTALLED_VERSIONS="/root/installed-versions.txt"

ARG SDK_PACKAGES_LIST="${DIRWORK}/packages.txt"

ENV ANDROID_HOME="/opt/android-sdk" \
    ANDROID_SDK_HOME="/opt/android-sdk" \
    ANDROID_NDK="/opt/android-sdk/ndk/latest" \
    ANDROID_NDK_ROOT="/opt/android-sdk/ndk/latest" \
    JENV_ROOT="/opt/jenv"
ENV ANDROID_SDK_MANAGER=${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager

ENV TZ=America/Los_Angeles

# Set locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"

# Variables must be referenced after they are created
ENV ANDROID_SDK_HOME="$ANDROID_HOME"
ENV ANDROID_NDK_HOME="$ANDROID_NDK"

ENV PATH="${JENV_ROOT}/shims:${JENV_ROOT}/bin:$JAVA_HOME/bin:$PATH:$ANDROID_SDK_HOME/emulator:$ANDROID_SDK_HOME/cmdline-tools/latest/bin:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$ANDROID_NDK"

#----------~~~~~~~~~~*****
# build stage: pre-base
#----------~~~~~~~~~~*****
FROM ubuntu as pre-base
ARG TERM=dumb \
    DEBIAN_FRONTEND=noninteractive

WORKDIR ${DIRWORK}

RUN uname -a && uname -m

# support amd64 and arm64
RUN JDK_PLATFORM=$(if [ "$(uname -m)" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    echo export JDK_PLATFORM=$JDK_PLATFORM >> /etc/jdk.env && \
    echo export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-$JDK_PLATFORM/" >> /etc/jdk.env && \
    echo . /etc/jdk.env >> /etc/bash.bashrc && \
    echo . /etc/jdk.env >> /etc/profile

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get clean && \
    apt-get update -qq && \
    apt-get install -qq -y apt-utils locales && \
    locale-gen $LANG

# Installing packages
RUN apt-get update -qq > /dev/null && \
    apt-get install -qq --no-install-recommends \
        autoconf \
        build-essential \
        cmake \
        ninja-build \
        curl \
        file \
        git \
        git-lfs \
        gpg-agent \
        less \
        libc6-dev \
        libgmp-dev \
        libmpc-dev \
        libmpfr-dev \
        libxslt-dev \
        libxml2-dev \
        m4 \
        ncurses-dev \
        ocaml \
        openjdk-8-jdk \
        openjdk-11-jdk \
        openjdk-17-jdk \
        openssh-client \
        pkg-config \
        software-properties-common \
        tzdata \
        unzip \
        vim-tiny \
        wget \
        zip \
        zipalign \
        s3cmd \
        zlib1g-dev > /dev/null && \
    git lfs install > /dev/null && \
    echo "JVM directories: `ls -l /usr/lib/jvm/`" && \
    . /etc/jdk.env && \
    echo "Java version (default):" && \
    java -version && \
    echo "set timezone" && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get -y clean && apt-get -y autoremove && rm -rf /var/lib/apt/lists/* && \
    rm -rf ${DIRWORK}/* /var/tmp/* && \
    echo 'debconf debconf/frontend select Dialog' | debconf-set-selections

#----------~~~~~~~~~~*****
# build stage: pre-minimal
#----------~~~~~~~~~~*****
FROM pre-base as pre-minimal
ARG DEBUG
# The `yes` is for accepting all non-standard tool licenses.
RUN mkdir --parents "$ANDROID_HOME/.android/" && \
    echo '### User Sources for Android SDK Manager' > \
        "$ANDROID_HOME/.android/repositories.cfg" && \
    . /etc/jdk.env && \
    yes | $ANDROID_SDK_MANAGER --licenses > /dev/null

# List all available packages.
# redirect to a temp file ${SDK_PACKAGES_LIST} for later use and avoid showing progress
RUN . /etc/jdk.env && \
    $ANDROID_SDK_MANAGER --list > ${SDK_PACKAGES_LIST} && \
    cat ${SDK_PACKAGES_LIST} | grep -v '='

RUN echo "platform tools" && \
    . /etc/jdk.env && \
    yes | $ANDROID_SDK_MANAGER ${DEBUG:+--verbose} \
        "platform-tools" > /dev/null

#----------~~~~~~~~~~*****
# build stage: base
#----------~~~~~~~~~~*****
FROM pre-minimal as base
RUN mkdir --parents "$ANDROID_HOME" && \
    unzip -q sdk-tools.zip -d "$ANDROID_HOME" && \
    cd "$ANDROID_HOME" && \
    mv cmdline-tools latest && \
    mkdir cmdline-tools && \
    mv latest cmdline-tools && \
    rm --force ${DIRWORK}/sdk-tools.zip

# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/

#----------~~~~~~~~~~*****
# build stage: jenv-final
#----------~~~~~~~~~~*****
# jenv
# Add jenv to control which version of java to use, default to 17.
FROM base as jenv-base
RUN echo '#!/usr/bin/env bash' >> ~/.bash_profile && \
    echo 'eval "$(jenv init -)"' >> ~/.bash_profile

FROM jenv-base as jenv-tagged
RUN git clone --depth 1 --branch ${JENV_RELEASE} https://github.com/jenv/jenv.git ${JENV_ROOT} && \
    echo "JENV_RELEASE=${JENV_RELEASE}" >> ${INSTALLED_TEMP}

FROM jenv-base as jenv-latest
RUN git clone  https://github.com/jenv/jenv.git ${JENV_ROOT} && \
    cd ${JENV_ROOT} && echo "JENV_RELEASE=$(git describe --tags HEAD)" >> ${INSTALLED_TEMP}

FROM jenv-${JENV_TAGGED} as jenv-final
RUN . ~/.bash_profile && \
    . /etc/jdk.env && \
    java -version && \
    jenv add /usr/lib/jvm/java-8-openjdk-$JDK_PLATFORM && \
    jenv add /usr/lib/jvm/java-11-openjdk-$JDK_PLATFORM && \
    jenv add /usr/lib/jvm/java-17-openjdk-$JDK_PLATFORM && \
    jenv versions && \
    jenv global 17.0 && \
    java -version

#----------~~~~~~~~~~*****
# build stage: ndk-final
#----------~~~~~~~~~~*****
# NDK (side-by-side)
FROM pre-minimal as ndk-base
WORKDIR ${DIRWORK}
RUN echo "NDK"

FROM ndk-base as ndk-tagged
RUN echo "Installing ${NDK_VERSION}" && \
    . /etc/jdk.env && \
    yes | $ANDROID_SDK_MANAGER ${DEBUG:+--verbose} "ndk;${NDK_VERSION}" > /dev/null && \
    ln -sv $ANDROID_HOME/ndk/${NDK_VERSION} ${ANDROID_NDK}

FROM ndk-base as ndk-latest
RUN NDK=$(grep 'ndk;' ${SDK_PACKAGES_LIST} | sort | tail -n1 | awk '{print $1}') && \
    NDK_VERSION=$(echo $NDK | awk -F\; '{print $2}') && \
    echo "Installing $NDK" && \
    . /etc/jdk.env && \
    yes | $ANDROID_SDK_MANAGER ${DEBUG:+--verbose} "$NDK" > /dev/null && \
    ln -sv $ANDROID_HOME/ndk/$NDK_VERSION ${ANDROID_NDK}

FROM ndk-${NDK_TAGGED} as ndk-final
RUN echo "NDK finished"

#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
#                FINAL BUILD TARGETS
#----------~~~~~~~~~~**********~~~~~~~~~~~-----------#
# All stages which follow are intended to be used as a final target
# for use by users. Otherwise known as production ready.

#----------~~~~~~~~~~*****
# build target: minimal
#----------~~~~~~~~~~*****
FROM pre-minimal as minimal
COPY --from=jenv-final ${JENV_ROOT} ${JENV_ROOT}
COPY --from=jenv-final ${INSTALLED_TEMP} ${DIRWORK}/.jenv_version
COPY --from=jenv-final /root/.bash_profile /root/.bash_profile

RUN chmod 775 -R $ANDROID_HOME && \
    git config --global --add safe.directory ${JENV_ROOT} && \
    cat ${DIRWORK}/.jenv_version >> ${INSTALLED_VERSIONS} && \
    rm -rf ${DIRWORK}/* && \
    echo "Android SDKs, Build tools, etc Installed: " >> ${INSTALLED_VERSIONS} && \
    . /etc/jdk.env && \
    ${ANDROID_SDK_MANAGER} --list_installed | tail --lines=+2 >> ${INSTALLED_VERSIONS}

WORKDIR ${FINAL_DIRWORK}

#----------~~~~~~~~~~*****
# build target: complete
#----------~~~~~~~~~~*****
FROM minimal as complete
COPY --from=ndk-final --chmod=775 ${ANDROID_NDK_ROOT}/../ ${ANDROID_NDK_ROOT}/../

RUN chmod 775 $ANDROID_HOME $ANDROID_NDK_ROOT/../ && \
    git config --global --add safe.directory ${JENV_ROOT} && \
    rm -rf ${DIRWORK}/* && \
    echo "Android SDKs, Build tools, etc Installed: " >> ${INSTALLED_VERSIONS} && \
    . /etc/jdk.env && \
    ${ANDROID_SDK_MANAGER} --list_installed | tail --lines=+2 >> ${INSTALLED_VERSIONS} && \
    ls -l $ANDROID_HOME && \
    ls -l $ANDROID_HOME/ndk && \
    ls -l $ANDROID_HOME/ndk/* && \
    du -sh $ANDROID_HOME

WORKDIR ${FINAL_DIRWORK}

# labels, see http://label-schema.org/
LABEL maintainer="Ming Chen"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.name="mingc/android-build-box"
LABEL org.label-schema.version="${DOCKER_TAG}"
LABEL org.label-schema.usage="/README.md"
LABEL org.label-schema.docker.cmd="docker run --rm -v `pwd`:${FINAL_DIRWORK} mingc/android-build-box bash -c './gradlew build'"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.vcs-ref="${SOURCE_COMMIT}@${SOURCE_BRANCH}"
