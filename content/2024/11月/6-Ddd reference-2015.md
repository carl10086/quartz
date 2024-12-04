
## refer

- [Domain-Driven Design Reference](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)
- [jmolecules](https://github.com/xmolecules/jmolecules/tree/main)



## 1-Intro

`Eric Evans` 2015 年左右出的东西. 

**1)-10年**

1. `DDD` 的核心理念 抗住了 时间的考验 ;
2. 软件开发方式的演进没有使用 `DDD` 过时, `Greg Young`, `Udi Dahan` 等等提出的 `CQRS` 和 `EDA` 已经成为了 系统架构中主流的选择;
3. 之后出现有趣的技术和框架, `Qi4J`, `Naked Objects`, `Roo` 等实验 也有重要的价值;

**2)-layered arch**


```java

/**
 * Identifies the {@link ApplicationLayer} in a layered architecture. The application layer is coordinating the
 * execution of business flows without containing business rules, but by utilizing the {@link DomainLayer}. It also
 * coordinates flows spanning other systems or bounded contexts and may keep information of the progress of the
 * execution.
 * <p>
 * Therefore, the application layer is a thin layer to enable the system to execute business flows.
 *
 * @author Christian Stettler
 * @author Henning Schwentner
 * @author Stephan Pirnbaum
 * @author Martin Schimak
 * @author Oliver Drotbohm
 * @see <a href="https://domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf">Domain-Driven Design
 *      Reference (Evans) - Layered Architecture</a>
 */
@Retention(RetentionPolicy.RUNTIME)
@Target({ ElementType.PACKAGE, ElementType.TYPE })
@Documented
public @interface ApplicationLayer {}
```