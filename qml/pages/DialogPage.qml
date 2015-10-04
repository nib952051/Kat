/*
  Copyright (C) 2015 Petr Vytovtov
  Contact: Petr Vytovtov <osanwe@protonmail.ch>
  All rights reserved.

  This file is part of Kat.

  Kat is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Kat is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Kat.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.0
import Sailfish.Silica 1.0
import "../views"
import "../js/storage.js" as StorageJS
import "../js/types.js" as TypesJS
import "../js/api/messages.js" as MessagesAPI
import "../js/api/users.js" as UsersAPI

Page {
    id: dialogPage

    property string fullname
    property int dialogId
    property bool isChat
    property bool isOnline
    property string lastSeenTime
    property string avatarSource
    property string userAvatar

    property Item contextMenu

    property int messagesOffset: 0

    property variant chatUsers

    property string attachmentsList: ""

    function formNewDialogMessages() {
        console.log('formNewDialogMessages()')
        loadingMessagesIndicator.running = true
        var messagesArray = StorageJS.getLastMessagesForDialog(dialogId)
        for (var item in messagesArray) formMessageList(messagesArray[item])
        scrollMessagesToBottom()

        if (isChat) MessagesAPI.api_getChatUsers(dialogId)
        else UsersAPI.getUsersAvatarAndOnlineStatus(dialogId)
    }

    function saveUsers(users) {
        chatUsers = users
        pageContainer.pushAttached(Qt.resolvedUrl("../pages/ChatUsersPage.qml"),
                                   { "chatTitle": fullname, "users": users })
        MessagesAPI.api_getHistory(isChat, dialogId, messagesOffset)
    }

    function updateDialogInfo(index, avatarURL, name, online, lastSeen) {
        avatarSource = avatarURL
        console.log(avatarSource)
        fullname = name
        isOnline = online
        lastSeenTime = lastSeen
        MessagesAPI.api_getHistory(isChat, dialogId, messagesOffset)
    }

    function sendMessage() {
        MessagesAPI.api_sendMessage(isChat, dialogId, encodeURIComponent(messageInput.text), attachmentsList, false)
        messageInput.text = ""
        attachmentsList = ""
    }

    function formMessagesListFromServerData(messagesArray) {
        if (messagesOffset === 0) messages.model.clear()
        for (var item in messagesArray) {
            var messageData = messagesArray[item]
            if (isChat) {
                console.log("chat")
                for (var index in chatUsers) if (chatUsers[index].id === messageData.fromId) {
                        messageData.avatarSource = chatUsers[index].photo
                        break
                    }
            }
            else {
                console.log('user')
                messageData.avatarSource = avatarSource
            }
            console.log(messageData.avatarSource + ' | ' + avatarSource)
            formMessageList(messageData)
        }
        scrollMessagesToBottom()
    }

    function formMessageList(messageData, insertToEnd) {
        var index = (insertToEnd === true) ? messages.model.count : 0;
        messageData.userAvatar = userAvatar
        messages.model.insert(index, messageData)
    }

    function scrollMessagesToBottom() {
        if (messagesOffset === 0) {
            messages.positionViewAtEnd()
        } else {
            messages.positionViewAtIndex(49, ListView.Beginning)
        }
    }

    function stopBusyIndicator() {
        loadingMessagesIndicator.running = false
    }

    function getUnreadMessagesFromModel() {
        var messagesIdsList = ""
        var index = 0
        while (index < messages.model.count) {
            console.log(index)
            if (messages.model.get(index).readState === 0) {
                console.log(messages.model.get(index).mid)
                messagesIdsList += "," + messages.model.get(index).mid
            }
            index += 1
        }
        console.log(messagesIdsList)
        return messagesIdsList.length !== 0 ? messagesIdsList.substring(1) : messagesIdsList
    }

    function markDialogAsRead() {
        var unreadMessagesIds = getUnreadMessagesFromModel()
        if (unreadMessagesIds.length > 0)
            MessagesAPI.api_markDialogAsRead(isChat, dialogId, unreadMessagesIds)
    }

    BusyIndicator {
        id: loadingMessagesIndicator
        anchors.centerIn: parent
        size: BusyIndicatorSize.Large
        running: false //true
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: dialogPage.height

        Label {
            id: dialogTitle
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingLarge
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor
            height: Theme.fontSizeLarge + 3 * Theme.paddingLarge
            verticalAlignment: Text.AlignVCenter
            text: fullname
        }

        Switch {
            id: dialogOnlineStatus
            anchors.verticalCenter: dialogTitle.verticalCenter
            anchors.right: dialogTitle.left
            anchors.rightMargin: Theme.paddingMedium
            automaticCheck: false
            height: Theme.fontSizeLarge
            width: Theme.fontSizeLarge
            checked: isOnline
        }

        SilicaListView {
            id: messages
            anchors.fill: parent
            anchors.topMargin: dialogTitle.height
            anchors.bottomMargin: messageInput.height
            clip: true

            model: ListModel {}

            header: Button {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width / 3 * 2
                text: qsTr("Загрузить больше")
                onClicked: {
                    loadingMessagesIndicator.running = true
                    messagesOffset = messagesOffset + 50;
                    MessagesAPI.api_getHistory(isChat, dialogId, messagesOffset)
                }
            }

            footer: Label {
                width: parent.width
                height: (isChat || isOnline) ? 0 : Theme.itemSizeSmall
                visible: !(isChat || isOnline)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignBottom
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
                text: qsTr("Был(a) в сети: %1").arg(lastSeenTime)
            }

            delegate: Item {
                id: messageItem

                property bool menuOpen: contextMenu != null && contextMenu.parent === messageItem

                height: menuOpen ? contextMenu.height + contentItem.height : contentItem.height
                width: parent.width

                MessageItem {
                    id: contentItem
                    width: parent.width

//                    onClicked: {
//                        dialogPage.pageContainer.push(Qt.resolvedUrl("MessagePage.qml"),
//                                                      { "fullname": dialogTitle.text,
//                                                        "isOnline": dialogOnlineStatus.isOnline,
//                                                        "messageText": message,
//                                                        "attachments": attachments })
//                    }
                    onPressAndHold: {
                        console.log(index)
                        if (!contextMenu)
                            contextMenu = contextMenuComponent.createObject(messages)
                        contextMenu.show(messageItem)
                    }
                }

                Component {
                    id: contextMenuComponent

                    ContextMenu {

                        property string message

                        MenuItem {
                            text: qsTr("Копировать текст")
                            onClicked: Clipboard.text = messages.model.get(index).message
                        }

                        onClosed: contextMenu = null
                    }
                }
            }

            VerticalScrollDecorator {}

            function lookupItem(itemId, fromEnd) {
                fromEnd = fromEnd === true

                for (var i = (fromEnd ? messages.model.count - 1 : 0);
                             (fromEnd ? i >= 0 : i < messages.model.count);
                             (fromEnd ? --i : ++i)) {
                    if (messages.model.get(i).mid === itemId) {
                        return i
                    }
                }
                console.log("Message with id '" + itemId + "' does not exist")
                return -1
            }
        }

        IconButton {
            id: attachmentsButton
            anchors.left: parent.left
            anchors.leftMargin: Theme.paddingLarge
            anchors.verticalCenter: messageInput.verticalCenter
            width: Theme.iconSizeSmallPlus
            height: Theme.iconSizeSmallPlus
            icon.width: Theme.iconSizeSmallPlus
            icon.height: Theme.iconSizeSmallPlus
            icon.fillMode: Image.PreserveAspectFit
            icon.source: "image://theme/icon-m-attach"
        }

        Label {
            id: attachmentsCounter
            anchors.verticalCenter: attachmentsButton.top
            anchors.left: attachmentsButton.left
            anchors.leftMargin: text === "10" ? 0 : Theme.paddingSmall
            anchors.verticalCenterOffset: Theme.paddingSmall
            font.bold: true
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.highlightColor
            text: {
                var attachmentsCount = attachmentsList.split(',').length - 1
                return attachmentsCount > 0 ? attachmentsCount : ""
            }
        }

        TextArea {
            id: messageInput
            anchors.bottom: parent.bottom
            anchors.left: attachmentsButton.right
            anchors.right: parent.right
            placeholderText: qsTr("Сообщение:")
            label: qsTr("Сообщение")

            EnterKey.enabled: text.length > 0
            EnterKey.iconSource: "image://theme/icon-m-enter-accept"
            EnterKey.onClicked: sendMessage()
        }

        PushUpMenu {

            MenuItem {
                text: qsTr("Обновить")
                onClicked: {
                    markDialogAsRead()
                    messages.model.clear()
                    messagesOffset = 0
                    loadingMessagesIndicator.running = true
                    MessagesAPI.api_getHistory(isChat, dialogId, messagesOffset)
                }
            }

            MenuItem {
                text: qsTr("Прикрепить изображение")
                onClicked: {
                    var imagePicker = pageStack.push("Sailfish.Pickers.ImagePickerPage")
                    imagePicker.selectedContentChanged.connect(function () {
                        loadingMessagesIndicator.running = true
                        photos.attachImage(imagePicker.selectedContent, "MESSAGE", 0)
                    })
                }
            }
        }
    }

    Connections {
        target: photos
        onImageUploaded: {
            attachmentsList += imageName + ","
            loadingMessagesIndicator.running = false
        }
    }

    onStatusChanged:
        if (status === PageStatus.Inactive) {
            markDialogAsRead()
        } else if (status === PageStatus.Active) {
            formNewDialogMessages()
        }

    function addNewMessage(jsonMessage) {
        var fromId = jsonMessage.fromId
        if (isChat)
            fromId -= 2000000000

        if (dialogId === fromId) {
            var messageData = MessagesAPI.parseMessage(jsonMessage)
            formMessageList(messageData, true)
            scrollMessagesToBottom()
        }
    }

    function updateMessageFlags(msgId, flags, action, userId) {
        if (isChat)
            userId -= 2000000000

        if (dialogId === userId) {
            var msgIndex = messages.lookupItem(msgId)
            if (msgIndex !== -1) {
                switch (action) {
                case TypesJS.Action.ADD:
                case TypesJS.Action.SET:
                    if ((flags & 1) === 1) {
                        messages.model.setProperty(msgIndex, "readState", 0)
                    }
                    break
                case TypesJS.Action.DEL:
                    if ((flags & 1) === 1) {
                        messages.model.setProperty(msgIndex, "readState", 1)
                    }
                    break
                }
            }
        }
    }

    function updateFriendStatus(userId, status) {
        if (!isChat && dialogId === userId) {
            isOnline = status
            dialogOnlineStatus.checked = status
        }
    }

    Component.onCompleted: {
        MessagesAPI.signaller.endLoading.connect(stopBusyIndicator)
        MessagesAPI.signaller.friendChangeStatus.connect(updateFriendStatus)
        MessagesAPI.signaller.changedMessageFlags.connect(updateMessageFlags)
        MessagesAPI.signaller.gotChatUsers.connect(saveUsers)
        MessagesAPI.signaller.gotHistory.connect(formMessagesListFromServerData)
        MessagesAPI.signaller.gotNewMessage.connect(addNewMessage)
        MessagesAPI.signaller.needScrollToBottom.connect(scrollMessagesToBottom)
        UsersAPI.signaller.endLoading.connect(stopBusyIndicator)
        UsersAPI.signaller.gotDialogInfo.connect(updateDialogInfo)
    }

    Component.onDestruction: {
        MessagesAPI.signaller.endLoading.disconnect(stopBusyIndicator)
        MessagesAPI.signaller.friendChangeStatus.disconnect(updateFriendStatus)
        MessagesAPI.signaller.changedMessageFlags.disconnect(updateMessageFlags)
        MessagesAPI.signaller.gotChatUsers.disconnect(saveUsers)
        MessagesAPI.signaller.gotHistory.disconnect(formMessagesListFromServerData)
        MessagesAPI.signaller.gotNewMessage.disconnect(addNewMessage)
        MessagesAPI.signaller.needScrollToBottom.disconnect(scrollMessagesToBottom)
        UsersAPI.signaller.endLoading.disconnect(stopBusyIndicator)
        UsersAPI.signaller.gotDialogInfo.disconnect(updateDialogInfo)
    }
}
