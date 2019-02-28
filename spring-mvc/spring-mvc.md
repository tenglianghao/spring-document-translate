# Web on Servlet Stack

Version 5.1.5.RELEASE

***

这部分文档介绍了对构建在Servlet API上并部署到Servlet容器上的Servlet-stack web应用程序的支持。单独的章节包括`Spring MVC`、视图技术、`CORS`支持和`WebSocket`支持。有关`reactive-stack` 的web应用程序，请参见Reactive Stack.

## 1. Spring Web MVC

Spring Web MVC是基于Servlet API构建的原始Web框架，从一开始就包含在Spring框架中。正式的名称“Spring Web MVC”来自于它的源模块(spring-webmvc)的名称，但它更常被称为“Spring MVC”。

与Spring Web MVC并行，Spring Framework 5.0引入了一个reactive-stack 的Web框架，其名称“Spring WebFlux”也基于其源模块(Spring - WebFlux)。本节讨论Spring Web MVC。下一节将介绍Spring WebFlux。

### 1.1. DispatcherServlet

Spring MVC和许多其他web框架一样，是围绕前端控制器模式设计的，其中核心的Servlet —— DispatcherServlet提供了一个用于请求处理的共享算法，而实际工作是由可配置的委托组件执行的。该模型灵活，支持多种工作流。

与其它的Servlet一样，DispatcherServlet需要使用Java配置或web.xml根据Servlet规范进行声明和映射。然后，DispatcherServlet使用Spring配置来发现它需要的用于请求映射、视图解析、异常处理等的委托组件。

下面的Java配置示例注册并初始化DispatcherServlet，它由Servlet容器自动检测(参见Servlet Config):

```java
public class MyWebApplicationInitializer implements WebApplicationInitializer {

    @Override
    public void onStartup(ServletContext servletCxt) {

        // Load Spring web application configuration
        AnnotationConfigWebApplicationContext ac = new AnnotationConfigWebApplicationContext();
        ac.register(AppConfig.class);
        ac.refresh();

        // Create and register the DispatcherServlet
        DispatcherServlet servlet = new DispatcherServlet(ac);
        ServletRegistration.Dynamic registration = servletCxt.addServlet("app", servlet);
        registration.setLoadOnStartup(1);
        registration.addMapping("/app/*");
    }
}
```



> 除了直接使用ServletContext API，您还可以扩展AbstractAnnotationConfigDispatcherServletInitializer并覆盖特定的方法(参见Context Hierarchy示例)。

下面的web.xml配置示例注册并初始化DispatcherServlet:

```xml
<web-app>
    
    <listener>
        <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
    </listener>
    
    <context-param>
        <param-name>contextConfigLocation</param-name>
        <param-value>/WEB-INF/app-context.xml</param-value>
    </context-param>

    <servlet>
        <servlet-name>app</servlet-name>
        <servlet-class>org.springframework.web.servlet.DispatcherServlet</servlet-class>
        <init-param>
            <param-name>contextConfigLocation</param-name>
            <param-value></param-value>
        </init-param>
        <load-on-startup>1</load-on-startup>
    </servlet>

    <servlet-mapping>
        <servlet-name>app</servlet-name>
        <url-pattern>/app/*</url-pattern>
    </servlet-mapping>

</web-app>
```

> Spring Boot遵循不同的初始化顺序。Spring Boot不是连接到Servlet容器的生命周期中，而是使用Spring配置引导自身和嵌入式`Servlet`容器。在Spring配置中检测到过滤器和Servlet声明，并向Servlet容器注册。有关更多细节，请参见Spring Boot文档。

#### 1.1.1 Context Hierarchy

`DispatcherServlet`希望自己的配置有一个`WebApplicationContext`(普通`ApplicationContext`的扩展)。`WebApplicationContext`有一个`ServletContext`引用及它关联的`Servlet`的链接。它还绑定到`ServletContext`，这样应用程序就可以在```RequestContextUtils```上使用静态方法来查找`WebApplicationContext`(如果需要访问的话)。

对于许多应用程序来说，拥有一个`WebApplicationContext`既简单又足够。也可以有一个上下文层次结构，其中一个根`WebApplicationContext`跨多个`DispatcherServlet`(或其他Servlet)实例共享，每个实例具有自己的子`WebApplicationContext`配置。有关上下文层次结构特性的更多信息，请参见`ApplicationContext`的附加功能。

根`WebApplicationContext`通常包含基础设施bean，例如需要跨多个`Servlet`实例共享的数据存储库和业务服务。这些bean是有效继承的，可以在特定于`Servlet`的子`WebApplicationContext`中覆盖(即重新声明)，它通常包含给定`Servlet`的本地bean。下图显示了这种关系:

![](C:\Users\jack\Desktop\spring-translate\spring-mvc\mvc-context-hierarchy.png)

下面的例子配置了一个`WebApplicationContext`层次结构:

```java
public class MyWebAppInitializer extends AbstractAnnotationConfigDispatcherServletInitializer {

    @Override
    protected Class<?>[] getRootConfigClasses() {
        return new Class<?>[] { RootConfig.class };
    }

    @Override
    protected Class<?>[] getServletConfigClasses() {
        return new Class<?>[] { App1Config.class };
    }

    @Override
    protected String[] getServletMappings() {
        return new String[] { "/app1/*" };
    }
}
```

> 如果不需要应用程序上下文层次结构，应用程序可以通过getRootConfigClasses()返回所有配置，并从`getServletConfigClasses()`返回`null`。

下面的例子展示了web.xml的等价版本:

```xml
<web-app>

    <listener>
        <listener-class>org.springframework.web.context.ContextLoaderListener</listener-class>
    </listener>

    <context-param>
        <param-name>contextConfigLocation</param-name>
        <param-value>/WEB-INF/root-context.xml</param-value>
    </context-param>

    <servlet>
        <servlet-name>app1</servlet-name>
        <servlet-class>org.springframework.web.servlet.DispatcherServlet</servlet-class>
        <init-param>
            <param-name>contextConfigLocation</param-name>
            <param-value>/WEB-INF/app1-context.xml</param-value>
        </init-param>
        <load-on-startup>1</load-on-startup>
    </servlet>

    <servlet-mapping>
        <servlet-name>app1</servlet-name>
        <url-pattern>/app1/*</url-pattern>
    </servlet-mapping>

</web-app>
```

> 如果不需要应用程序上下文层次结构，应用程序可以只配置“根”上下文，并将contextConfigLocation Servlet参数保留为空。

#### 1.1.2 Special Bean Types

`DispatcherServlet`将委托给特殊bean来处理请求并呈现适当的响应。“特殊bean”指的是实现框架契约的spring管理的对象实例。它们通常带有内置的契约，但是您可以自定义它们的属性并扩展或替换它们。

下表列出了`DispatcherServlet`检测到的特殊bean：

| Bean Type                                | 说明                                                         |
| :--------------------------------------- | ------------------------------------------------------------ |
| `HandlerMapping`                         | 将请求与用于预处理和后处理的拦截器列表一起映射到处理程序。映射基于一些标准，这些标准的细节因`HandlerMapping`实现的不同而不同。<br />两个主要的`HandlerMapping`实现是`RequestMappingHandlerMapping`(它支持`@RequestMapping`注释的方法)和`SimpleUrlHandlerMapping`(它为处理程序维护URI路径模式的显式注册)。 |
| `HandlerAdapter`                         | 帮助`DispatcherServlet`调用映射到请求的处理程序，而不管该处理程序实际是如何调用的。例如，调用带注释的控制器需要解析注释。`HandlerAdapter`的主要目的是保护`DispatcherServlet`不受这些细节的影响。 |
| `HandlerExceptionResolver`               | 解决异常的策略，可能将异常映射到处理程序、HTML错误视图或其他目标。看到异常。 |
| `ViewResolver`                           | 将处理程序返回的基于逻辑字符串的视图名称解析为要呈现给响应的实际视图。参见视图解析和视图技术。 |
| `LocaleResolver`,`LocaleContextResolver` | 解析客户端使用的语言环境，可能还有他们所在的时区，以便能够提供国际化的视图。看地区。 |
| `ThemeResolver`                          | 解决web应用程序可以使用的主题——例如，提供个性化的布局。参见 Themes |
| `MultipartResolver`                      | 使用某个多部分解析库解析多部分请求(例如，浏览器表单文件上传)的抽象。看到几部分的解析器。 |
| `FlashMapManager`                        | 存储和检索“输入”和“输出”FlashMap，可以使用它们将属性从一个请求传递到另一个请求，通常是通过重定向。看到Flash属性。 |



#### 1.1.3. Web MVC Config

应用程序可以声明在处理请求所需的特殊Bean类型中列出的基础设施Bean。`DispatcherServlet`检查每个特殊bean的`WebApplicationContext`。如果没有匹配的bean类型，则返回到`DispatcherServlet.properties`中列出的默认类型。

在大多数情况下，MVC配置是最好的起点。它以Java或XML声明所需的bean，并提供高级配置回调API来定制它

> Spring Boot依赖于MVC Java配置来配置Spring MVC，并提供了许多额外的方便选项。

####   1.1.4. Servlet Config



















































































































