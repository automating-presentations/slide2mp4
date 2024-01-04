FROM fedora:39
LABEL maintainer="Hirofumi Kojima"
# podman build -t slide2mp4:latest <PATH_OF_DOCKERFILE>


RUN dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-39.noarch.rpm \
                   awscli bc ffmpeg-free file git google-noto-sans*-cjk-jp-fonts parallel \
                   poppler python3 libxml2 wget zip && \
    dnf -y update && \
    dnf clean all


RUN git clone --depth 1 https://github.com/automating-presentations/slide2mp4 && \
    cp slide2mp4/slide2mp4.sh /usr/local/bin/slide2mp4 && \
    cp slide2mp4/tools/chapters-timestamp.sh /usr/local/bin/chapters-timestamp && \
    cp slide2mp4/tools/lexicon-generate.sh /usr/local/bin/lexicon-generate && \
    cp slide2mp4/tools/lexicon2dic.sh /usr/local/bin/lexicon2dic && \
    cp slide2mp4/tools/talkscripts-extraction.sh /usr/local/bin/talkscripts-extraction && \
    chmod +x /usr/local/bin/* && \
    cp -r slide2mp4/lib /usr/local/bin/ && \
    chmod +x /usr/local/bin/lib/*.sh && \
    rm -rf slide2mp4
