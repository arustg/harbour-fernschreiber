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
import QtQuick 2.5
import QtGraphicalEffects 1.0
import QtMultimedia 5.0
import Sailfish.Silica 1.0
import Nemo.Notifications 1.0
import WerkWolf.Fernschreiber 1.0
import "../components"
import "../js/twemoji.js" as Emoji
import "../js/functions.js" as Functions

Page {
    id: overviewPage
    allowedOrientations: Orientation.All

    property bool initializationCompleted: false;
    property bool loading: true;
    property int authorizationState: TelegramAPI.Closed
    property int connectionState: TelegramAPI.WaitingForNetwork
    property int ownUserId;
    property bool chatListCreated: false;

    onStatusChanged: {
        if (status === PageStatus.Active && initializationCompleted && !chatListCreated) {
            updateContent();
        }
    }

    Connections {
        target: dBusAdaptor
        onPleaseOpenMessage: {
            console.log("[OverviewPage] Opening chat from external call...")
            if (chatListCreated) {
                if (status !== PageStatus.Active) {
                    pageStack.pop(pageStack.find( function(page){ return(page._depth === 0)} ), PageStackAction.Immediate);
                }
                pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), { "chatInformation" : tdLibWrapper.getChat(chatId) });
            }
        }
    }

    Timer {
        id: chatListCreatedTimer
        interval: 300
        running: false
        repeat: false
        onTriggered: {
            overviewPage.chatListCreated = true;
            chatListModel.redrawModel();
        }
    }

    function setPageStatus() {
        switch (overviewPage.connectionState) {
        case TelegramAPI.WaitingForNetwork:
            pageStatus.color = "red";
            pageHeader.title = qsTr("Waiting for network...");
            break;
        case TelegramAPI.Connecting:
            pageStatus.color = "gold";
            pageHeader.title = qsTr("Connecting to network...");
            break;
        case TelegramAPI.ConnectingToProxy:
            pageStatus.color = "gold";
            pageHeader.title = qsTr("Connecting to proxy...");
            break;
        case TelegramAPI.ConnectionReady:
            pageStatus.color = "green";
            pageHeader.title = qsTr("Fernschreiber");
            break;
        case TelegramAPI.Updating:
            pageStatus.color = "lightblue";
            pageHeader.title = qsTr("Updating content...");
            break;
        }
    }

    function updateContent() {
        tdLibWrapper.getChats();
    }

    function initializePage() {
        overviewPage.authorizationState = tdLibWrapper.getAuthorizationState();
        overviewPage.handleAuthorizationState();
        overviewPage.connectionState = tdLibWrapper.getConnectionState();
        overviewPage.setPageStatus();
    }

    function handleAuthorizationState() {
        switch (overviewPage.authorizationState) {
        case TelegramAPI.WaitPhoneNumber:
        case TelegramAPI.WaitCode:
        case TelegramAPI.WaitPassword:
        case TelegramAPI.WaitRegistration:
            overviewPage.loading = false;
            pageStack.push(Qt.resolvedUrl("../pages/InitializationPage.qml"));
            break;
        case TelegramAPI.AuthorizationReady:
            overviewPage.loading = false;
            overviewPage.initializationCompleted = true;
            overviewPage.updateContent();
            break;
        default:
            // Nothing ;)
        }
    }

    Connections {
        target: tdLibWrapper
        onAuthorizationStateChanged: {
            overviewPage.authorizationState = authorizationState;
            handleAuthorizationState();
        }
        onConnectionStateChanged: {
            overviewPage.connectionState = connectionState;
            setPageStatus();
        }
        onOwnUserIdFound: {
            overviewPage.ownUserId = ownUserId;
        }
        onChatLastMessageUpdated: {
            if (!overviewPage.chatListCreated) {
                chatListCreatedTimer.restart();
            }
        }
        onChatOrderUpdated: {
            if (!overviewPage.chatListCreated) {
                chatListCreatedTimer.restart();
            }
        }
        onChatsReceived: {
            if(chats && chats.chat_ids && chats.chat_ids.length === 0) {
                chatListCreatedTimer.restart();
            }
        }
    }

    Component.onCompleted: {
        initializePage();
    }

    SilicaFlickable {
        id: overviewContainer
        contentHeight: parent.height
        contentWidth: parent.width
        anchors.fill: parent
        visible: !overviewPage.loading

        PullDownMenu {
            MenuItem {
                text: qsTr("About Fernschreiber")
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("../pages/SettingsPage.qml"))
            }
        }

        Column {
            id: column
            width: parent.width
            height: parent.height
            spacing: Theme.paddingMedium

            Row {
                id: headerRow
                width: parent.width

                GlassItem {
                    id: pageStatus
                    width: Theme.itemSizeMedium
                    height: Theme.itemSizeMedium
                    color: "red"
                    falloffRadius: 0.1
                    radius: 0.2
                    cache: false
                }

                PageHeader {
                    id: pageHeader
                    title: qsTr("Fernschreiber")
                    width: parent.width - pageStatus.width
                }
            }

            Item {
                id: chatListItem
                width: parent.width
                height: parent.height - Theme.paddingMedium - headerRow.height

                SilicaListView {

                    id: chatListView

                    anchors.fill: parent

                    clip: true
                    opacity: overviewPage.chatListCreated ? 1 : 0
                    Behavior on opacity { NumberAnimation {} }

                    model: chatListModel
                    delegate: ListItem {

                        id: chatListViewItem

                        contentHeight: chatListRow.height + chatListSeparator.height + 2 * Theme.paddingMedium
                        contentWidth: parent.width

                        onClicked: {
                            pageStack.push(Qt.resolvedUrl("../pages/ChatPage.qml"), { "chatInformation" : display });
                        }

                        showMenuOnPressAndHold: chat_id != overviewPage.ownUserId
                        menu: ContextMenu {
                            MenuItem {
                                onClicked: {
                                    var newNotificationSettings = display.notification_settings;
                                    if (newNotificationSettings.mute_for > 0) {
                                        newNotificationSettings.mute_for = 0;
                                    } else {
                                        newNotificationSettings.mute_for = 6666666;
                                    }
                                    tdLibWrapper.setChatNotificationSettings(chat_id, newNotificationSettings);
                                }
                                text: display.notification_settings.mute_for > 0 ? qsTr("Unmute Chat") : qsTr("Mute Chat")
                            }
                        }

                        Column {
                            id: chatListColumn
                            width: parent.width - ( 2 * Theme.horizontalPageMargin )
                            spacing: Theme.paddingSmall
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                verticalCenter: parent.verticalCenter
                            }

                            Row {
                                id: chatListRow
                                width: parent.width
                                height: chatListContentColumn.height
                                spacing: Theme.paddingMedium

                                Column {
                                    id: chatListPictureColumn
                                    width: chatListContentColumn.height - Theme.paddingSmall
                                    height: chatListContentColumn.height - Theme.paddingSmall
                                    anchors.verticalCenter: parent.verticalCenter

                                    Item {
                                        id: chatListPictureItem
                                        width: parent.width
                                        height: parent.width

                                        ProfileThumbnail {
                                            id: chatListPictureThumbnail
                                            photoData: photo_small
                                            replacementStringHint: chatListNameText.text
                                            width: parent.width
                                            height: parent.width
                                            forceElementUpdate: overviewPage.chatListCreated
                                        }

                                        Rectangle {
                                            id: chatUnreadMessagesCountBackground
                                            color: Theme.highlightBackgroundColor
                                            width: Theme.fontSizeLarge
                                            height: Theme.fontSizeLarge
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            radius: parent.width / 2
                                            visible: unread_count > 0
                                        }

                                        Text {
                                            id: chatUnreadMessagesCount
                                            font.pixelSize: Theme.fontSizeExtraSmall
                                            font.bold: true
                                            color: Theme.primaryColor
                                            anchors.centerIn: chatUnreadMessagesCountBackground
                                            visible: chatUnreadMessagesCountBackground.visible
                                            text: unread_count > 99 ? "99+" : unread_count
                                        }
                                    }
                                }

                                Column {
                                    id: chatListContentColumn
                                    width: parent.width * 5 / 6 - Theme.horizontalPageMargin
                                    spacing: Theme.paddingSmall

                                    Text {
                                        id: chatListNameText
                                        text: title ? Emoji.emojify(title, Theme.fontSizeMedium) + ( display.notification_settings.mute_for > 0 ? Emoji.emojify(" 🔇", Theme.fontSizeMedium) : "" ) : qsTr("Unknown")
                                        textFormat: Text.StyledText
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.primaryColor
                                        elide: Text.ElideRight
                                        width: parent.width
                                        onTruncatedChanged: {
                                            // There is obviously a bug in QML in truncating text with images.
                                            // We simply remove Emojis then...
                                            if (truncated) {
                                                text = text.replace(/\<img [^>]+\/\>/g, "");
                                            }
                                        }
                                    }

                                    Row {
                                        id: chatListLastMessageRow
                                        width: parent.width
                                        spacing: Theme.paddingSmall
                                        Text {
                                            id: chatListLastUserText
                                            text: is_channel ? "" : ( last_message_sender_id ? ( last_message_sender_id !== overviewPage.ownUserId ? Emoji.emojify(Functions.getUserName(tdLibWrapper.getUserInformation(last_message_sender_id)), font.pixelSize) : qsTr("You") ) : qsTr("Unknown") )
                                            font.pixelSize: Theme.fontSizeExtraSmall
                                            color: Theme.highlightColor
                                            textFormat: Text.StyledText
                                            onTruncatedChanged: {
                                                // There is obviously a bug in QML in truncating text with images.
                                                // We simply remove Emojis then...
                                                if (truncated) {
                                                    text = text.replace(/\<img [^>]+\/\>/g, "");
                                                }
                                            }
                                        }
                                        Text {
                                            id: chatListLastMessageText
                                            text: last_message_text ? Emoji.emojify(last_message_text, Theme.fontSizeExtraSmall) : qsTr("Unknown")
                                            font.pixelSize: Theme.fontSizeExtraSmall
                                            color: Theme.primaryColor
                                            width: parent.width - Theme.paddingMedium - chatListLastUserText.width
                                            elide: Text.ElideRight
                                            textFormat: Text.StyledText
                                            onTruncatedChanged: {
                                                // There is obviously a bug in QML in truncating text with images.
                                                // We simply remove Emojis then...
                                                if (truncated) {
                                                    text = text.replace(/\<img [^>]+\/\>/g, "");
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        id: messageContactTimeElapsedText
                                        text: last_message_date ? Functions.getDateTimeElapsed(last_message_date) : qsTr("Unknown")
                                        font.pixelSize: Theme.fontSizeTiny
                                        color: Theme.secondaryColor
                                    }
                                }
                            }

                        }

                        Separator {
                            id: chatListSeparator

                            anchors {
                                top: chatListColumn.bottom
                                topMargin: Theme.paddingMedium
                            }

                            width: parent.width
                            color: Theme.primaryColor
                            horizontalAlignment: Qt.AlignHCenter
                        }

                    }

                    ViewPlaceholder {
                        enabled: chatListView.count === 0
                        text: qsTr("You don't have any chats yet.")
                    }

                    VerticalScrollDecorator {}
                }

                Column {
                    width: parent.width
                    height: loadingLabel.height + loadingBusyIndicator.height + Theme.paddingMedium
                    spacing: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter

                    opacity: overviewPage.chatListCreated ? 0 : 1
                    Behavior on opacity { NumberAnimation {} }
                    visible: !overviewPage.chatListCreated

                    InfoLabel {
                        id: loadingLabel
                        text: qsTr("Loading chat list...")
                    }

                    BusyIndicator {
                        id: loadingBusyIndicator
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: !overviewPage.chatListCreated
                        size: BusyIndicatorSize.Large
                    }
                }


            }


        }

    }

}
