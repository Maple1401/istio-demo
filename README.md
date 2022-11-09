
> 此仓库方便快速安装 istio 1.13.2 及 bookinfo 、kiali-travel demo

## Istio

Istio 的流量管理本质上是将流量与基础设施解耦，让运维人员可以通过Pilot指定流量遵循什么规则，而不是指定哪些pod虚拟机应该接收流量，这样通过Pilot和智能Envoy代理就可以进行流量控制。例如，你可以通过Pilot指定特定服务的5%流量转到金丝雀版本，而不必考虑金丝雀部署的大小，或根据请求的内容将流量发送到特定版本。很明显，将流量管理与基础设施扩缩分离开来，使得系统可提供独立于应用代码的多种功能，例如A/B测试、金丝雀发布等机制所依赖的动态请求路由。此外，Istio还使用超时、重试和熔断器来处理故障恢复，并使用故障注入来跨服务测试故障恢复政策的兼容性。这些功能都是通过在服务网格中部署的Sidecar代理Envoy来实现的。

## 概念

- Sidecar（边车）：Sidecar自定义资源描述了Sidecar代理的配置，该代理协调与其连接的工作负载实例的入站和出站通信。默认情况下，Istio将为网格中的所有Sidecar代理进行配置，使其具有到达网格中每个工作负载实例所需的必要配置，并接受与工作负载关联的所有端口上的流量。Sidecar资源提供了一种细粒度调整端口、协议的方法，使得代理能接受向工作负载转发流量或从工作负载转发流量。此外，可以限制代理在从工作负载实例转发出站流量时可以达到的服务集。
- 服务（Service）：绑定到服务注册表中唯一名称的应用程序行为单位。服务由运行在pod、容器、虚拟机上的工作负载实例实现的多个网络端点组成。
- 服务版本（Service versions）：也称为子集（subsets），在持续部署场景中，对于给定服务，可能会存在运行着应用程序二进制文件的不同变种的不同实例子集。这些变种不一定是不同的API版本，也可以是对同一服务的迭代更改，部署在不同的环境中，如生产环境、预发环境或者开发测试环境等。
- 源（Source）：调用目标服务的下游客户端。
- 主机（Host）：客户端在尝试连接服务时使用的地址
- 访问模型（Access model）：应用程序在不知道各个服务版本（子集）的情况下仅对目标服务（主机）进行寻址。版本的实际选择由Sidecar代理确定，使应用程序代码能够脱离依赖服务的演变。
- 虚拟服务（Virtual Service）：一个虚拟服务定义了一系列针对指定服务的流量路由规则。每个路由规则都针对特定协议定义流量匹配规则。如果流量符合这些特征，就会根据规则发送到服务注册表中的目标服务（或者目标服务的子集或版本）。
- 目标规则（Destination Rule）：目标规则定义了在路由发生后应用于服务的流量的策略。这些规则指定负载均衡的配置，来自Sidecar代理的连接池大小以及异常检测设置，以便从负载均衡池中检测和驱逐不健康的主机。


## 安装 Istio 及 BookInfo Demo

### 脚本一键安装

可使用脚本一键安装，将仓库下载到部署主机，进入文件夹后执行 `bash istio-demo.sh install`，最后会输出访问信息

提供功能：
- 安装 istio demo 配置
- 部署 bookinfo demo
- 部署 travel demo （需按提示写本地 hosts 域名进行访问）
- 关闭 mTLS 加密
- jaeger grafana 等附加组件默认使用 NodePort

### 自行安装

如需自定义，官方中文文档很详细，按文档步骤安装即可 https://istio.io/latest/zh/docs/setup/getting-started/

## 经验技巧
- istioctl 安装如果较慢，可自行下载 istioctl 后上传至服务器
- 所涉及环境变量可写入到 `~/.bash_profile` 持久化保存  e.g. `export PATH=$PWD/bin:$PATH > ~/.bash_profile`
- 可在命令行持续访问 demo 页面 `watch -n 1 curl -o /dev/null -s -w %{http_code} $GATEWAY_URL/productpage`

## 如何关闭 mTls 加密

- 配置 istio 所在命名空间，则为全局配置

```
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: "default"
  namespace: "istio-system"
spec:
  mtls:
    mode: DISABLE
EOF
```

参考 [全局以严格模式启用 Istio 双向 TLS](https://istio.io/latest/zh/docs/tasks/security/authentication/authn-policy/#globally-enabling-Istio-mutual-TLS-in-STRICT-mode)
## 如何访问  Kiali 仪表板、 以及 Prometheus、 Grafana、 还有 Jaeger

Kiali 相当于 istio Web 端，可在页面控制所有 istio 功能及流量拓扑查询。

- istioctl dashboad --help 查询所有附加组件
- istioctl dashboard  --address=0.0.0.0 jaeger &
- 或者把 service 改成 nodePort 形式


## 安装 Kiali Travel Demo

第二个 Demo ，比 BookInfo 组件更多，可在前端控制访问请求速率，更适合学习

https://kiali.io/docs/tutorials/travels/03-first-steps/

- 按文档中需配置本地 hosts control.travel-control.istio-cluster.org  指向NodeIP，再用浏览器访问 control.travel-control.istio-cluster.org（需要加 istio-grateway nodePort 端口号访问）

