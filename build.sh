#!/bin/bash

new_images=$(date +"%d.%m.%y_%H.%M")
GITHUB="https://github.com/bartolamey/task_three.git"

#---------------Пременные почты------------------------------------------------------------------------------------------------------------------------------------------------#
FROM=DevOPS@orange.soft
MAILTO_DEVOPS=7987575@gmail.com
MAILTO_DEVELOPER=bartolamey@gmail.com
NAME="Bartoshuk Vadim"
BODY_OK="Всё выполнено, сайт доступен по адресу ec2-18-191-32-154.us-east-2.compute.amazonaws.com"
BODY_ERROR="Произошла ошибка, билд не создан, лог отправлен DevOPS"
BODY_ERROR_DEVOPS="Билд не выполнился, читай log"
SMTPSERVER=smtp.gmail.com:587
SMTPLOGIN=$(cat /root/.auth/auth_gmail | head -n1 | tail -n1)
SMTPPASS=$(cat /root/.auth/auth_gmail | head -n2 | tail -n1)
#-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#

echo "ID работающего контейнера"
old_container=$(docker ps -q)
echo $old_container
sleep 1

echo "Проверяем есть ли новая версия"
sleep 1

cd ~/devops/task_three
git pull >> pull_ress 2>&1
_pull_ress=$(cat pull_ress)
cd ..

#-----------------Build---------------------------------------------------------------------------------------------------------------------------------------------------------#
if [ "$_pull_ress" = "Already up to date." ]
then
	echo "Нет изменений в рипозиторие, нечего билдить =("
	rm ~/devops/task_three/pull_ress
	sleep 1
	exit
else
	rm ~/devops/task_three/pull_ress
	echo "Есть изменения. Архивируем предыдущий каталог сайта"
	zip -r ~/devops/backup_$new_images.zip ~/devops/task_three/ >> ~/devops/log 2>&1
	sleep 1

	echo "Останавливаем" $old_container
	docker stop $old_container >> ~/devops/log 2>&1
	sleep 1

	echo "Создаём новый образ"
	docker build -t $new_images . >> ~/devops/log 2>&1
	sleep 1

	echo "Новый образ" $new_images
	sleep 1

	echo "Запускаем новый контейнер"
	docker run -d -p 80:80 $new_images >> ~/devops/log 2>&1
	new_container=$(docker ps -q)

	echo "Новый ID" $new_container
	sleep 1
fi

#----------------Проверка------------------------------------------------------------------------------------------------------------------------------------------------------
if [ "$new_container" = "$old_container" ]; then
	echo "Запушен старый контейнер, что то пошло не так =("
	echo "Отправляем письмо c log файлом Devops"
	/usr/bin/sendEmail -f $FROM -t $MAILTO_DEVELOPER -o message-charset=utf-8 -u $NAME -m $BODY_ERROR -s $SMTPSERVER -o tls=yes -xu $SMTPLOGIN -xp $SMTPPASS
	/usr/bin/sendEmail -f $FROM -t $MAILTO_DEVOPS -o message-charset=utf-8 -u $NAME -m $BODY_ERROR_DEVOPS -a log -s $SMTPSERVER -o tls=yes -xu $SMTPLOGIN -xp $SMTPPASS
	sleep 1

elif [ -z "$new_container" ]; then
	echo "Нет запушеных контейнеров, запускаю предыдущий контейнер =("
	echo "Отправляем письмо c log файлом Devops"
	/usr/bin/sendEmail -f $FROM -t $MAILTO_DEVELOPER -o message-charset=utf-8 -u $NAME -m $BODY_ERROR -s $SMTPSERVER -o tls=yes -xu $SMTPLOGIN -xp $SMTPPASS
	/usr/bin/sendEmail -f $FROM -t $MAILTO_DEVOPS -o message-charset=utf-8 -u $NAME -m $BODY_ERROR_DEVOPS -a log -s $SMTPSERVER -o tls=yes -xu $SMTPLOGIN -xp $SMTPPASS
	docker start $old_container
	sleep 1
else
	echo "Всё отлично, удаляю не нужный файлы, отправляем письмо разработчику =)"
	/usr/bin/sendEmail -f $FROM -t $MAILTO_DEVELOPER -o message-charset=utf-8 -u $NAME -m $BODY_OK -s $SMTPSERVER -o tls=yes -xu $SMTPLOGIN -xp $SMTPPASS
	docker rm $old_container >> ~/devops/log 2>&1
	docker rmi -f $(docker images -q) >> ~/devops/log 2>&1
	rm ~/devops/log
	sleep 1
fi
