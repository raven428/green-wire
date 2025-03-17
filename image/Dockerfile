# kics-scan disable=b03a748a-542d-44f4-bb86-9199ab4fd2d5,aa93e17f-b6db-4162-9334-c70334e7ac28,fd54f200-402c-4333-a5a4-36ef6709af2f
FROM openwrt/imagebuilder:mediatek-filogic-23.05.5
COPY --chown=buildbot:buildbot files /builder/files
RUN /builder/files/install.sh
