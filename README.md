# 1. CI/CD para IBM API Gateway

Ejemplo de CI/CD para IBM API Gateway basado en una arquitectura simplificada de microservicios, contenedores Docker y pipeline de Jenkins como código.

## 1.1. Tabla de Contenidos

<!-- TOC -->

- [1. CI/CD para IBM API Gateway](#1-cicd-para-ibm-api-gateway)
  - [1.1. Tabla de Contenidos](#11-tabla-de-contenidos)
  - [1.2. Diagrama de depliegue](#12-diagrama-de-depliegue)
  - [1.3. Componentes](#13-componentes)
    - [1.3.1. Jenkins](#131-jenkins)
      - [1.3.1.1. Plugins](#1311-plugins)
      - [1.3.1.2. Nodo o agente remoto](#1312-nodo-o-agente-remoto)
        - [1.3.1.2.1. Aprovisionamiento del nodo remoto](#13121-aprovisionamiento-del-nodo-remoto)
        - [1.3.1.2.2. Configuración del nodo remoto en Jenkins](#13122-configuración-del-nodo-remoto-en-jenkins)
        - [1.3.1.2.3. Pipelines](#13123-pipelines)
          - [1.3.1.2.3.1. Pipeline promoción ambiente de testing](#131231-pipeline-promoción-ambiente-de-testing)
          - [1.3.1.2.3.2. Pipeline línea principal estable](#131232-pipeline-línea-principal-estable)
        - [1.3.1.2.2. Proyectos](#13122-proyectos)
          - [1.3.1.2.2.1. Proyecto promoción ambiente de testing](#131221-proyecto-promoción-ambiente-de-testing)
          - [1.3.1.2.2.2. Proyecto línea principal estable](#131222-proyecto-línea-principal-estable)
    - [1.3.2. Docker](#132-docker)
      - [1.3.2.1. Motor docker en nodo remoto](#1321-motor-docker-en-nodo-remoto)
      - [1.3.2.2. Imagen API Connect Developer Toolkit](#1322-imagen-api-connect-developer-toolkit)
      - [1.3.2.3. Imagen Newman](#1323-imagen-newman)
    - [1.3.3. GitLab](#133-gitlab)
      - [1.3.3.1. Repositorio de ejemplo](#1331-repositorio-de-ejemplo)
      - [1.3.3.2. Conexión SSH (entre GitLab y Jenkins)](#1332-conexión-ssh-entre-gitlab-y-jenkins)
      - [1.3.3.3. Configuración Webhook (entre GitLab y Jenkins)](#1333-configuración-webhook-entre-gitlab-y-jenkins)
    - [1.3.4. Biblioteca de imágenes](#134-biblioteca-de-imágenes)

<!-- /TOC -->

## 1.2. Diagrama de depliegue

CI/CD para IBM API Gateway necesita de las herramientas [Jenkins](https://www.jenkins.io/), [GitLab](https://about.gitlab.com/) y [Docker](https://www.docker.com/) para poder funcionar como un Sistema de Integración Continua integrado.

Se utilizó como integrador Jenkins Pipeline porque es la herramienta más utilizada en la comunidad de GitHub a la fecha tomando en cuenta la cantidad de commits realizados sobre los distintos proyectos. 

Obviamente, este escenario se puede replicar a otros sistemas CI/CD ya que el mismo se ejecuta sobre imágenes docker.

![](/docs/deployment_diagram.jpg)

## 1.3. Componentes

### 1.3.1. Jenkins

Para el ejemplo empleamos la versión de Jenkins 2.121.3.

Lea la página [Installing Jenkins](https://www.jenkins.io/doc/book/installing/) para obtener más información acerca de la instalación de Jenkins.

También, puede acceder al enlace [CI/CD con Jenkins](http://10.1.1.35:55013/) para ver como quedo configurado el ambiente de la prueba de concepto.

#### 1.3.1.1. Plugins

A continuación se enumeran los plugins necesarios en Jenkins para poder lograr CI/CD para IBM API Gateway:

- [Gitlab Plugin](https://plugins.jenkins.io/gitlab-plugin/)
- [Git Plugin](https://plugins.jenkins.io/git/)
- [Git Client Plugin](https://plugins.jenkins.io/git-client/)
- [Docker Plugin](https://plugins.jenkins.io/docker-plugin/)
- [Pipeline Plugin](https://plugins.jenkins.io/workflow-aggregator/)
- [Gitlab Hook Plugin](https://plugins.jenkins.io/gitlab-hook/)

#### 1.3.1.2. Nodo o agente remoto

Empleamos un mecanismo eficiente para la automatización de las tareas realizadas durante el proceso de CI/CD mediante el diseño de pipelines que describen las secuencias de instrucciones con la ayuda de imagenes Docker. 

Por ello para poder ejecutar las imagenes Docker, que llevarán adelante las tareas de automatización, necesitamos conectar nuestro nodo principal de Jenkins con un nodo remoto que tiene instalado el motor de Docker. 

Recordemos que un nodo o agente remoto Jenkins es típicamente una maquina o contenedor que se conecta con el nodo principal de Jenkins y ejecuta las tareas ordenadas por el propio nodo principal.

##### 1.3.1.2.1. Aprovisionamiento del nodo remoto

Ud. puede seguir los siguientes pasos para aprovisionar el nodo remoto:

- Confirmar que tiene una versión Java instalada mediante el comando: *java -version*. Para este ejemplo hemos empleado openjdk versión 1.8.0_191.
- Crear un directorio de trabajo para el nodo principal sobre el nodo remoto. Por ejemplo: /home/jenkins.
- Copiar el archivo [slave.jar](files/slave.jar) al directorio del nodo remoto.
- Ejecutar desde el terminal del nodo remoto:

```console
*bash -c cd "/root/archivos/jenkins" && java  -jar slave.jar*
```

##### 1.3.1.2.2. Configuración del nodo remoto en Jenkins

Ud. puede seguir los siguientes pasos para configurar el nodo remoto en Jenkins:

- En el nodo principal de Jenkins ir a Manage Jenkins > Manage Nodes.
- Crear un nuevo nodo indicando su nombre y el tipo *nodo o agente permanente*.
- Configurar el nuevo nodo creado los siguientes valores:
    - **# of executors** Cantidad de compilaciones que pueden correr al mismo tiempo en este agente. Por defecto uno (1).
    - **Remote root directory** Directorio de trabajo creado en el nodo remoto. Por ejemplo: /home/jenkins.
    - **Launch Method** Método de comunicación entre el nodo principal y el nodo remoto. Aquí el nodo principal se conecta 
    al nodo remoto usando el protocolo SSH. Elija la opción **Launch slave agents via SSH**. 
    - **Host** Dirección del nodo remoto donde el agente se ejecuta.
    - **Credentials** Las credenciales en caso de que dicho anfitrión las requiera. Para este ejemplo usamos el tipo de 
    credencial *Username with password*.

##### 1.3.1.2.3. Pipelines

La integración entre Jenkins, IBM API Gateway y GitLab requiere de dos pipelines por cada proyecto de desarrollo de api. El [pipeline promoción ambiente de Testing](#131231-pipeline-promoción-ambiente-de-testing) nos permitirá la promoción del ambiente de desarrollo al ambiente de testing. El [pipeline línea principal estable](#131232-pipeline-línea-principal-estable) garantizará que las integraciones en la línea principal del proyecto sean estables.

###### 1.3.1.2.3.1. Pipeline promoción ambiente de testing 

Puede acceder al archivo [jenkinsfile-promote-dev2test](./resources/jenkinsfile/jenkinsfile-promote-dev2test) para conocer como esta implementada la promoción del ambiente de desarrollo al ambiente de testing.

###### 1.3.1.2.3.2. Pipeline línea principal estable

Puede acceder al archivo [jenkinsfile-check-status-master](./resources/jenkinsfile/jenkinsfile-check-status-master) para conocer como esta implementado el aseguramiento de la estabilidad de la línea master.

##### 1.3.1.2.2. Proyectos 

Es necesaria la creación de dos proyectos en Jenkins por cada proyecto de desarrollo de api. El [proyecto promoción ambiente de Testing](#131221-proyecto-promoción-ambiente-de-testing) nos permitirá hacer uso del [pipeline promoción ambiente de Testing](#131231-pipeline-promoción-ambiente-de-testing) en tanto que, el [proyecto línea principal estable](#131222-proyecto-línea-principal-estable), posibilitará el empleo del [pipeline línea principal estable](#131232-pipeline-línea-principal-estable).

###### 1.3.1.2.2.1. Proyecto promoción ambiente de testing 

Puede acceder al archivo [api-promote-dev2test.xml](./jobs/api-promote-dev2test.xml) para conocer como esta implementada la promoción del ambiente de desarrollo al ambiente de testing.
 
###### 1.3.1.2.2.2. Proyecto línea principal estable

Puede acceder al archivo [api-check-status-master.xml](./jobs/api-check-status-master.xml) para conocer como esta implementada el aseguramiento de la estabilidad de la línea master.

### 1.3.2. Docker

#### 1.3.2.1. Motor docker en nodo remoto

CI/CD para IBM API Gateway requiere que el nodo remoto, utilizado como esclavo del nodo principal de Jenkins, ejecute el motor de Docker. Para el ejemplo empleamos las siguientes versiones de docker:

```console
Client:
 Version:           18.06.1-ce
 API version:       1.38
 Go version:        go1.10.3
 Git commit:        e68fc7a
 Built:             Tue Aug 21 17:23:03 2018
 OS/Arch:           linux/amd64
 Experimental:      false

Server:
 Engine:
  Version:          18.06.1-ce
  API version:      1.38 (minimum version 1.12)
  Go version:       go1.10.3
  Git commit:       e68fc7a
  Built:            Tue Aug 21 17:25:29 2018
  OS/Arch:          linux/amd64
  Experimental:     false
```

Lea la página [Get Docker](https://docs.docker.com/get-docker/) para obtener más información acerca de la instalación de Docker.

#### 1.3.2.2. Imagen API Connect Developer Toolkit

Las secuencias de instrucciones declaradas en los pipelines de Jenkins para efectuar las actividades de integración y despliegue sobre el IBM API Gateway se apoyan sobre IBM API Connect Toolkit. El toolkit incluye una herramienta de línea de comandos llamada apic, la cual nos permite gestionar el ciclo de vida de una API dentro de IBM API Gateway.

Fue generada una imagen Docker liviana, independiente y ejecutable que incluye IBM API Connect Toolkit y todo lo necesario para ejecutar las actividades de integración y despliegue sobre IBM API Gateway.

Puede acceder a la imagen [ndigrazia/apic](https://hub.docker.com/r/ndigrazia/apic) sobre el repositorio Docker Hub o ejecutar la misma dentro de un contenedor con el comando:

```console
docker run --rm -it ndigrazia/apic:1.0.0 bash
```

Puede acceder al archivo [apic.dockerfile](resources/dockerfile/apic.dockerfile) para conocer como esta construido el dockerfile de la imagen.

#### 1.3.2.3. Imagen Newman

Los proyectos de desarrollos de APIs disponen de la herramienta [Postman](https://www.postman.com/) para crear entornos de trabajo diferentes y para la elaboración de casos de pruebas que permiten validar el comportamiento de las APIs. Postman es un cliente REST basado en una interfaz grafica de usuario que 
no permite a los desarrolladores integrar las pruebas construidas en la herramienta sobre Sistemas de Integración Continuas como Jenkins Pipeline.

Newman es un componente javascript que se enfoca en ejecutar los casos de pruebas, escritos en Postmnan, directamente desde la línea de comando para facilitar la integración de las pruebas con Sistemas de Integración Continuas.

Puede acceder al repositorio Docker Hub que contiene la imagen [postman/newman](https://hub.docker.com/r/postman/newman/) usada por el pipeline [proyecto línea principal estable](#131222-proyecto-línea-principal-estable). 

También, puede ejecutar un contenedor con el siguiente comando: 

```
#Enlace una carpeta collections ~/collections sobre /etc/newman para que el 
#contenedor pueda acceder a las colleciones de postman

docker run -v ~/collections:/etc/postman -t postman/newman [file_name].json.postman_collection \ 
  --environment="[file_name].json.postman_environment" 
```

### 1.3.3. GitLab

#### 1.3.3.1. Repositorio de ejemplo

#### 1.3.3.2. Conexión SSH (entre GitLab y Jenkins)

La integración entre Jenkins y GitLab requiere de una conexión mediante un par de claves SSH pública y privada. Empleamos la herramienta *PuTTYgen* para crear nuestro par de claves SSH pública y privada. 

Puede acceder a la página [PuTTYgen](https://www.puttygen.com/) para conocer como instalar y como usar la herramienta PuTTYgen para producir el par de claves SSH pública y privada.

Puede acceder al link [Adding an SSH key to your GitLab account](https://docs.gitlab.com/ee/ssh/#adding-an-ssh-key-to-your-gitlab-account) para conocer como agregar la clave pública a GitLab.

Puede acceder a la página [Using credentials](https://www.jenkins.io/doc/book/using/using-credentials/#using-credentials) para conocer como agregar la clave privada a Jenkins. Recuerde que en Jenkins debe seleccionar el tipo de credencial *SSH Username with private key*, ingresar el usuario de GitLab elegido y por último, ingresar la clave privada generada.

#### 1.3.3.3. Configuración Webhook (entre GitLab y Jenkins)

Los eventos o cambios en el proyecto de desarrollo de api deben ser notificados por medio de webhooks. Estos webhooks permiten a Jenkins reaccionar ante distintos escenarios de modificaciones en el repositorio GitLab y actuar como respuesta a esos sucesos.

Puede acceder al link [Configure the GitLab project](https://docs.gitlab.com/ee/integration/jenkins.html#configure-the-gitlab-project) para conocer como configurar los eventos que notificarán a Jenkins sobre los cambios realizados en el repositorio.

Hemos configurado el tipo de evento *Merge request events* para informar a Jenkins sobre los cambios realizados por medio de la operación *Merge* sobre el repositorio del proyecto de desarrollo de la api.

Para asegurar que se ejecute el [pipeline promoción ambiente de Testing](#131231-pipeline-promoción-ambiente-de-testing) y el [pipeline línea principal estable](#131232-pipeline-línea-principal-estable) hemos configurado en el repositorio de GitLab un webhooks por cada uno de los pipelines.

### 1.3.4. Biblioteca de imágenes
