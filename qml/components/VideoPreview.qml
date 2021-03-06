/*
    Copyright (C) 2020 Sebastian J. Wolf

    This file is part of Fernschreiber.

    Fernschreiber is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Fernschreiber is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Fernschreiber. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.0
import "../js/functions.js" as Functions

Item {
    id: videoMessageComponent

    property variant videoData;
    property string videoUrl;
    property int previewFileId;
    property int videoFileId;
    property bool fullscreen : false;
    property bool onScreen;
    property string videoType : "video";
    property bool playRequested: false;

    width: parent.width
    height: parent.height

    Timer {
        id: screensaverTimer
        interval: 30000
        running: false
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            tdLibWrapper.controlScreenSaver(false);
        }
    }

    function getTimeString(rawSeconds) {
        var minutes = Math.floor( rawSeconds / 60 );
        var seconds = rawSeconds - ( minutes * 60 );

        if ( minutes < 10 ) {
            minutes = "0" + minutes;
        }
        if ( seconds < 10 ) {
            seconds = "0" + seconds;
        }
        return minutes + ":" + seconds;
    }

    function disableScreensaver() {
        screensaverTimer.start();
    }

    function enableScreensaver() {
        screensaverTimer.stop();
        tdLibWrapper.controlScreenSaver(true);
    }

    Component.onCompleted: {
        updateVideoThumbnail();
    }

    function updateVideoThumbnail() {
        if (videoData) {
            videoType = videoData['@type'];
            videoFileId = videoData[videoType].id;
            if (typeof videoData.thumbnail !== "undefined") {
                previewFileId = videoData.thumbnail.photo.id;
                if (videoData.thumbnail.photo.local.is_downloading_completed) {
                    placeholderImage.source = videoData.thumbnail.photo.local.path;
                } else {
                    tdLibWrapper.downloadFile(previewFileId);
                }
            } else {
                placeholderImage.source = "image://theme/icon-l-video?white";
                placeholderImage.width = Theme.itemSizeLarge
                placeholderImage.height = Theme.itemSizeLarge
            }
        }
    }

    function handlePlay() {
        playRequested = true;
        if (videoData[videoType].local.is_downloading_completed) {
            videoUrl = videoData[videoType].local.path;
            videoComponentLoader.active = true;
        } else {
            videoDownloadBusyIndicator.running = true;
            tdLibWrapper.downloadFile(videoFileId);
        }
    }

    Connections {
        target: tdLibWrapper
        onFileUpdated: {
            if (videoData) {
                if (fileInformation.local.is_downloading_completed && fileId === previewFileId) {
                    videoData.thumbnail.photo = fileInformation;
                    placeholderImage.source = fileInformation.local.path;
                }
                if (!fileInformation.remote.is_uploading_active && fileInformation.local.is_downloading_completed && fileId === videoFileId) {
                    videoDownloadBusyIndicator.running = false;
                    videoData[videoType] = fileInformation;
                    videoUrl = fileInformation.local.path;
                    if (onScreen && playRequested) {
                        playRequested = false;
                        videoComponentLoader.active = true;
                    }
                }
            }
        }
    }

    Image {
        id: placeholderImage
        width: parent.width
        height: parent.height
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready ? true : false
    }

    Image {
        id: imageLoadingBackgroundImage
        source: "../../images/background-" + ( Theme.colorScheme ? "black" : "white" ) + "-small.png"
        anchors {
            centerIn: parent
        }
        width: parent.width - Theme.paddingSmall
        height: parent.height - Theme.paddingSmall
        visible: placeholderImage.status !== Image.Ready
        asynchronous: true

        fillMode: Image.PreserveAspectFit
        opacity: 0.15
    }

    Rectangle {
        id: placeholderBackground
        color: "black"
        opacity: 0.3
        height: parent.height
        width: parent.width
        visible: playButton.visible
    }

    Row {
        width: parent.width
        height: parent.height
        Item {
            height: parent.height
            width: videoMessageComponent.fullscreen ? parent.width : ( parent.width / 2 )
            Image {
                id: playButton
                anchors.centerIn: parent
                width: Theme.iconSizeLarge
                height: Theme.iconSizeLarge
                source: "image://theme/icon-l-play?white"
                asynchronous: true
                visible: placeholderImage.status === Image.Ready ? true : false
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        fullscreenItem.visible = false;
                        handlePlay();
                    }
                }
            }
            BusyIndicator {
                id: videoDownloadBusyIndicator
                running: false
                visible: running
                anchors.centerIn: parent
                size: BusyIndicatorSize.Large
            }
        }
        Item {
            id: fullscreenItem
            height: parent.height
            width: parent.width / 2
            visible: !videoMessageComponent.fullscreen
            Image {
                id: fullscreenButton
                anchors.centerIn: parent
                width: Theme.iconSizeLarge
                height: Theme.iconSizeLarge
                asynchronous: true
                source: "../../images/icon-l-fullscreen.png"
                visible: ( placeholderImage.status === Image.Ready && !videoMessageComponent.fullscreen ) ? true : false
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        pageStack.push(Qt.resolvedUrl("../pages/VideoPage.qml"), {"videoData": videoData});
                    }
                }
            }
        }
    }

    Rectangle {
        id: videoErrorShade
        width: parent.width
        height: parent.height
        color: "lightgrey"
        visible: placeholderImage.status === Image.Error ? true : false
        opacity: 0.3
    }

    Rectangle {
        id: errorTextOverlay
        color: "black"
        opacity: 0.8
        width: parent.width
        height: parent.height
        visible: false
    }

    Text {
        id: errorText
        visible: false
        width: parent.width
        color: Theme.primaryColor
        font.pixelSize: Theme.fontSizeExtraSmall
        horizontalAlignment: Text.AlignHCenter
        anchors {
            verticalCenter: parent.verticalCenter
        }
        wrapMode: Text.Wrap
        text: ""
    }

    Loader {
        id: videoComponentLoader
        active: false
        width: parent.width
        height: Functions.getVideoHeight(parent.width, videoData)
        sourceComponent: videoComponent
    }

    Component {
        id: videoComponent

        Item {
            width: parent ? parent.width : 0
            height: parent ? parent.height : 0

            Connections {
                target: messageVideo
                onPlaying: {
                    playButton.visible = false;
                    placeholderImage.visible = false;
                    messageVideo.visible = true;
                }
            }

            Video {
                id: messageVideo

                Component.onCompleted: {
                    if (messageVideo.error === MediaPlayer.NoError) {
                        messageVideo.play();
                        timeLeftTimer.start();
                    } else {
                        errorText.text = qsTr("Error loading video! " + messageVideo.errorString)
                        errorTextOverlay.visible = true;
                        errorText.visible = true;
                    }
                }

                onStatusChanged: {
                    if (status == MediaPlayer.NoMedia) {
                        console.log("No Media");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.Loading) {
                        console.log("Loading");
                        videoBusyIndicator.visible = true;
                    }
                    if (status == MediaPlayer.Loaded) {
                        console.log("Loaded");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.Buffering) {
                        console.log("Buffering");
                        videoBusyIndicator.visible = true;
                    }
                    if (status == MediaPlayer.Stalled) {
                        console.log("Stalled");
                        videoBusyIndicator.visible = true;
                    }
                    if (status == MediaPlayer.Buffered) {
                        console.log("Buffered");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.EndOfMedia) {
                        console.log("End of Media");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.InvalidMedia) {
                        console.log("Invalid Media");
                        videoBusyIndicator.visible = false;
                    }
                    if (status == MediaPlayer.UnknownStatus) {
                        console.log("Unknown Status");
                        videoBusyIndicator.visible = false;
                    }
                }

                visible: false
                width: parent.width
                height: parent.height
                source: videoUrl
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (messageVideo.playbackState === MediaPlayer.PlayingState) {
                            enableScreensaver();
                            messageVideo.pause();
                            timeLeftItem.visible = true;
                        } else {
                            disableScreensaver();
                            messageVideo.play();
                            timeLeftTimer.start();
                        }
                    }
                }
                onStopped: {
                    enableScreensaver();
                    messageVideo.visible = false;
                    placeholderImage.visible = true;
                    playButton.visible = true;
                    videoComponentLoader.active = false;
                    fullscreenItem.visible = !videoMessageComponent.fullscreen;
                }
            }

            BusyIndicator {
                id: videoBusyIndicator
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                visible: false
                running: visible
                size: BusyIndicatorSize.Medium
                onVisibleChanged: {
                    if (visible) {
                        enableScreensaver();
                    } else {
                        disableScreensaver();
                    }
                }
            }

            Timer {
                id: timeLeftTimer
                repeat: false
                interval: 2000
                onTriggered: {
                    timeLeftItem.visible = false;
                }
            }

            Item {
                id: timeLeftItem
                width: parent.width
                height: parent.height
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                visible: messageVideo.visible
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation {} }

                Rectangle {
                    id: positionTextOverlay
                    color: "black"
                    opacity: 0.3
                    width: parent.width
                    height: parent.height
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: pausedRow.visible
                }

                Row {
                    id: pausedRow
                    width: parent.width
                    height: parent.height - ( messageVideoSlider.visible ? messageVideoSlider.height : 0 ) - ( positionText.visible ? positionText.height : 0 )
                    visible: videoComponentLoader.active && messageVideo.playbackState === MediaPlayer.PausedState
                    Item {
                        height: parent.height
                        width: videoMessageComponent.fullscreen ? parent.width : ( parent.width / 2 )
                        Image {
                            id: pausedPlayButton
                            anchors.centerIn: parent
                            width: Theme.iconSizeLarge
                            height: Theme.iconSizeLarge
                            asynchronous: true
                            source: "image://theme/icon-l-play?white"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    disableScreensaver();
                                    messageVideo.play();
                                    timeLeftTimer.start();
                                }
                            }
                        }
                    }
                    Item {
                        id: pausedFullscreenItem
                        height: parent.height
                        width: parent.width / 2
                        visible: !videoMessageComponent.fullscreen
                        Image {
                            id: pausedFullscreenButton
                            anchors.centerIn: parent
                            width: Theme.iconSizeLarge
                            height: Theme.iconSizeLarge
                            asynchronous: true
                            source: "../../images/icon-l-fullscreen.png"
                            visible: ( videoComponentLoader.active && messageVideo.playbackState === MediaPlayer.PausedState ) ? true : false
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    pageStack.push(Qt.resolvedUrl("../pages/VideoPage.qml"), {"videoData": videoData});
                                }
                            }
                        }
                    }
                }

                Slider {
                    id: messageVideoSlider
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: positionText.top
                    minimumValue: 0
                    maximumValue: messageVideo.duration ? messageVideo.duration : 0
                    stepSize: 1
                    value: messageVideo.position
                    enabled: messageVideo.seekable
                    visible: (messageVideo.duration > 0)
                    onReleased: {
                        messageVideo.seek(Math.floor(value));
                        messageVideo.play();
                        timeLeftTimer.start();
                    }
                    valueText: getTimeString(Math.round((messageVideo.duration - messageVideoSlider.value) / 1000))
                }

                Text {
                    id: positionText
                    visible: messageVideo.visible && messageVideo.duration === 0
                    color: Theme.primaryColor
                    font.pixelSize: videoMessageComponent.fullscreen ? Theme.fontSizeSmall : Theme.fontSizeTiny
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: Theme.paddingSmall
                        horizontalCenter: positionTextOverlay.horizontalCenter
                    }
                    wrapMode: Text.Wrap
                    text: ( messageVideo.duration - messageVideo.position ) > 0 ? getTimeString(Math.round((messageVideo.duration - messageVideo.position) / 1000)) : "-:-"
                }
            }

        }


    }

}
