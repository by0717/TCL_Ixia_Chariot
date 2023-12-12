### TCL_Ixia_Chariot 
### Uset tcl language to run chariot for auto test
<u> ** 在前端集成各种测速模块时候，遇到一个调用Ixiachairot 的困难，由于某原因大多数用的老版本还是32位，只提供C和tcl 的API 接口，
为了适配前端框架，较为灵活快速的方式，就只能采用python 调用tcl 32位脚本的方式，根据chariot 提供tcl api接口，个人进行了封装，
将log记录/CSV记录/ErrorCode 都封装好后调用，可以很快速的灵活的根据情况调用脚本（以便自动化调用），
并将结果获取到前端，鉴于时间原因，有需要的请github自取参考，1000行代码不容易，对您有帮助请github上点个赞 ** <u>
#### 前置条件：
 安装chairot 6.7 （其他版本未经过测试）和Endpoint 电脑 可以用64位，但是tcl 需要用32位，因Ixia chairot 只提供了32位 dll API接口
 tcl 需要安装tcllib 1.2.1
#### 使用方法：
  git 或者获取整个项目，可以放置在chariot 电脑，利用python 执行 ssh 或者其他远程协议，进行执行脚本，当然有兴趣可以用python 32位中tl/tk库进行转义执行，不做推荐
  生成结果可以存取到csv中，获取结果可以直接提起 如前端做图表，这里不扩展。

#### 脚本逻辑：
  将log/csv/error/yaml 文件封装，作为脚本中调用debug show results 的模块，yaml文件用来定制个人信息，可以增加，修改，
  将建立test对象/app对象/pair对象 分别独立封装，以便case中个性调用
     
#### 结构介绍：
Common 文件： 放置设置pair group test 对象，以及保存tst 显示结果
config 文件:  放置设置记录工具和设置路径的config配置文件
yaml 文件： 放置个性化定制条件
tcl_sample 文件： ixia chariot官方脚本
CSV 文件：存储CSV结果文件
logs 文件：存放log( 设计为类似python logging 或者loguru模式）
case 文件：存放自定义case模块，时间原因，这里只提供一个，后续有增加会更新
