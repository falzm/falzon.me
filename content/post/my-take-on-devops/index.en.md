---
type: post
title: My Take on DevOps
date: 2018-01-12
tags:
- DevOps
- rant
keywords:
- DevOps
- developer
- sysadmin
---

Disclaimer: this article will be a bit different than my usual technical posts.

I might be a little late to the party, but a recent conversation with a colleague has sparked the need for me to write down my take on the *DevOps* movement started a few years ago, and that is now all the rage.

Unless you've been living under a rock for the past years, if you're working in production IT you've heard about DevOps. Chances are you've probably been described by this term in your job description, and/or the team you're working in. Maybe you've used DevOps *tools*, or even *done* DevOps – used as a verb, "to DevOps". This is the problem right here: there is no official definition, only a vague consensus about the fundamental principles behind it. There is a [Wikipedia page][1] for it, but it doesn't mean that everybody agrees on what that means *in practice*. This is the topic of this post: how I've witnessed DevOps in real life over the past years.

Before relating my real life experience with DevOps I'll state my version of it.

DevOps is not a job title.

DevOps is not a team title.

DevOps is not a tool.

DevOps is not a synonym for *sysadmin*.

DevOps is not a synonym for *developer*.

To *me*, DevOps is what happens when developers and operators (commonly known as system administrators, or *sysadmins*) manage to work together seamlessly, being aware of each other's constraints. It is a *situation* where those two domains cooperate instead of fighting, understand and acknowledge each other's endgame. It is seeing the big picture. This is a *culture*, an *environment*. Tools might help providing it, job/team titles don't.

I've had the opportunity to witness what I believe the DevOps mentality to be just *once*, and it was a beautiful thing to see. It all started like any typical "devs vs ops" teams setup: developers were developing and shipping code with little to almost no regard to how it behaved once in production, and ops was being randomly paged at night because the service was broken or slow – without having the slightest clue as to why, randomly restarting back-end instances hoping it would solve the problems. Developers had almost no clue what the infrastructure running their code looked like. Sysadmins denied shell access to servers to developers, even read-only. New infrastructure components requirements – such as a new database software – introduced as side-effect of a new product features were communicated at the last moment, typically after the code had been implemented and was ready to ship. Oh by the way: it was sysadmins' job to learn about, deploy and manage those new technologies at scale and on-call within a few days.

{{< postimg file="that_would_be_great.jpg" >}}

As you can imagine this situation eventually led to frustration on both teams, but fortunately it was dealt with before it reached the point of no return. The VP of Engineering had just arrived in the company, and after a period of observation he decided to interview each member of both teams to hear their personal feeling about the current environment, then organised a global meeting with both teams present. During this meeting, everybody was invited to identify problems and write them down on Post-it notes. The notes were collected and each had to be explained to the audience by its author, then dispatched by broad themes – such as "trust", "responsability", "tooling" or "documentation". At the end of the meeting, a pair composed of one developer and one sysadmin were dealt with a group of issues described on Post-it notes, and tasked to solve them or present solutions to the team the next week. Every following week, the same people would meet and discuss their progress in solving the issues or explain why it couldn’t be solved. It took weeks, but most of the problems identified were solved, as communication between members of the two teams improved noticeably.

As leader of the ops team I took this road to improvement at heart, as it required strong cultural changes: stop infantilizing my fellow developers and trust them by default, provide them with shell access to production servers that would allow them to freely browse the infrastructure and see how their code runs live. In return, I demanded implication from them: I wanted them to care about their code in production, to regularly check logs and metrics when they deploy new code – and even when they don’t. The ops team started working on a convenient and reliable code deployment tool to replace the year-old hacky shellscripts provided to developers, making the deployment process more enjoyable. In return, I asked developers to provide us with relevant documentation for their back-end applications (e.g. list of service dependencies, useful metrics descriptions...); eventually, they even ended up managing and deploying application metrics collecting configuration using the infrastructure management tools on the production servers themselves.

A few weeks before I left this company, one of my last projects had been to design and implement a SLA-based monitoring system for our back-end application services, where developers would identify key performance metrics along with the accepted threshold beyond which a notification would be sent to the developers' Slack channel to let them know that something was requiring their attention. To me, we'd reached peak DevOps: developers and sysadmins collaborating to make each other's work better and share the responsibilities of running a service to users. Beyond tools, it requires communication, empathy, but also management support.

The sad reality is that for one correct implementation of the DevOps mentality, I've observed many broken, if not toxic ones. The vast majority consisted either in renaming the good ol' sysadmin job title as DevOps without changing its mission statement, or even worse – creating a new team of free roaming agents as a gateway between the developers and sysadmins in the hope of reducing the friction.

What's left of DevOps today is a *has-been* trendy word about to be eclipsed by a shiny new one: SRE – for *Site Reliability Engineering*, a term coined by Google for which [a whole book][0] was written. From what I've observed this last couple of years, SRE is poised to become the new DevOps, because it's easier for organizations to rebrand job/team titles than change their culture.

[0]: https://landing.google.com/sre/book.html
[1]: https://en.wikipedia.org/wiki/DevOps
